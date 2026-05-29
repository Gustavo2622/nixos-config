"""Textual TUI for the research-mining review queue.

One pending item at a time; navigate with n/p; act with a/m/s/R/e/x; quit q.
All DB writes go through `apply_review_decision()` in this module — the
review_queue row is marked resolved as the action's last step, so a crash
mid-action leaves the item pending for next time.
"""

from __future__ import annotations

from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import Container, Horizontal, Vertical
from textual.screen import ModalScreen
from textual.widgets import Footer, Header, Input, Label, Static

import ollama
import store


# ─── DB write side ─────────────────────────────────────────────────────────


def apply_review_decision(
    item: dict,
    decision: str,           # 'accept_new' | 'merge' | 'specialize' | 'related' | 'reject'
    *,
    target_id: int | None = None,
    new_statement: str | None = None,
) -> str:
    """Apply the decision to the DB. Returns a one-line note for resolution."""
    payload = item["payload"]
    extracted = payload.get("extracted", {})
    paper_id = item["source_paper_id"]
    statement = (new_statement or extracted.get("canonical_statement") or "").strip()
    problem_type = extracted.get("problem_type", "open_problem")
    role = extracted.get("role", "states")
    try:
        confidence = float(extracted.get("confidence", 0.5))
    except (TypeError, ValueError):
        confidence = 0.5
    confidence = max(0.0, min(1.0, confidence))
    evidence = extracted.get("evidence")

    # Look up paper category (problems carry it directly).
    rows = store.list_papers(limit=1)  # placeholder — we'll fetch by id instead
    category = None
    with store.connect() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT category FROM papers WHERE id = %s", (paper_id,))
            r = cur.fetchone()
            if r:
                category = r["category"]
    if not category:
        category = "crypto"

    note = ""
    if decision == "reject":
        note = "rejected"

    elif decision == "accept_new":
        vec = _embed_or_none(statement)
        new_id = store.insert_problem(
            canonical_statement=statement,
            problem_type=problem_type,
            category=category,
            embedding=vec,
        )
        store.add_paper_problem_edge(paper_id, new_id, role=role,
                                    confidence=confidence, evidence=evidence)
        note = f"accepted new problem #{new_id}"

    elif decision == "merge":
        if target_id is None:
            raise ValueError("merge requires target_id")
        store.add_problem_alias(target_id, statement)
        store.add_paper_problem_edge(paper_id, target_id, role=role,
                                    confidence=confidence, evidence=evidence)
        note = f"merged into #{target_id}"

    elif decision in ("specialize", "related"):
        if target_id is None:
            raise ValueError(f"{decision} requires target_id")
        vec = _embed_or_none(statement)
        new_id = store.insert_problem(
            canonical_statement=statement,
            problem_type=problem_type,
            category=category,
            embedding=vec,
        )
        kind = "specializes" if decision == "specialize" else "related"
        store.add_problem_problem_edge(parent_id=target_id, child_id=new_id, kind=kind)
        store.add_paper_problem_edge(paper_id, new_id, role=role,
                                    confidence=confidence, evidence=evidence)
        note = f"new problem #{new_id} {kind} #{target_id}"

    else:
        raise ValueError(f"unknown decision: {decision}")

    # Last step: mark resolved.
    with store.connect() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """UPDATE review_queue
                      SET status = %s, resolved_at = NOW(), resolution = %s
                    WHERE id = %s""",
                ("accepted" if decision != "reject" else "rejected", note, item["id"]),
            )
        conn.commit()
    return note


def _embed_or_none(text: str) -> list[float] | None:
    if not text.strip():
        return None
    try:
        v = ollama.embed(text)[0]
        return v or None
    except Exception:
        return None


def _fetch_problem(problem_id: int) -> dict | None:
    with store.connect() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id, canonical_statement, problem_type, status FROM problems WHERE id = %s",
                (problem_id,),
            )
            return cur.fetchone()


def _fetch_paper(paper_id: int) -> dict | None:
    with store.connect() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id, source, ext_id, title FROM papers WHERE id = %s",
                (paper_id,),
            )
            return cur.fetchone()


# ─── widgets ───────────────────────────────────────────────────────────────


class EditStatementScreen(ModalScreen[str | None]):
    """Modal: edit the canonical_statement of the current proposal."""

    BINDINGS = [
        Binding("escape", "cancel", "Cancel"),
    ]

    def __init__(self, current: str) -> None:
        super().__init__()
        self._current = current

    def compose(self) -> ComposeResult:
        yield Vertical(
            Label("Edit canonical statement (Enter to save, Esc to cancel):"),
            Input(value=self._current, id="edit-input"),
            id="edit-dialog",
        )

    def on_mount(self) -> None:
        self.query_one("#edit-input", Input).focus()

    def on_input_submitted(self, event: Input.Submitted) -> None:
        self.dismiss(event.value)

    def action_cancel(self) -> None:
        self.dismiss(None)


class ReviewApp(App):
    CSS = """
    Screen { layout: vertical; }
    #status { dock: top; height: 1; background: $panel; padding: 0 1; }
    #main   { padding: 1 2; }
    .label  { color: $text-muted; }
    .stmt   { color: $accent; padding-top: 1; }
    .small  { color: $text-muted; }
    .cand   { padding-left: 2; }
    #edit-dialog {
        align: center middle;
        width: 80%;
        height: auto;
        border: thick $accent;
        background: $panel;
        padding: 1 2;
    }
    """

    BINDINGS = [
        Binding("a", "accept", "Accept new"),
        Binding("m", "merge", "Merge → best"),
        Binding("s", "specialize", "Specialize of best"),
        Binding("R", "related", "Related to best"),
        Binding("e", "edit", "Edit"),
        Binding("x", "reject", "Reject"),
        Binding("n", "next", "Next"),
        Binding("p", "prev", "Prev"),
        Binding("q", "quit", "Quit"),
    ]

    def __init__(self) -> None:
        super().__init__()
        self._items: list[dict] = []
        self._idx: int = 0
        self._statement_override: str | None = None

    def on_mount(self) -> None:
        self._refresh_items(reset_index=True)

    def compose(self) -> ComposeResult:
        yield Header(show_clock=False)
        yield Static("", id="status")
        yield Container(Static("Loading…", id="body"), id="main")
        yield Footer()

    def _refresh_items(self, *, reset_index: bool) -> None:
        self._items = store.list_review_queue(status="pending", limit=500)
        if reset_index:
            self._idx = 0
        elif self._idx >= len(self._items):
            self._idx = max(0, len(self._items) - 1)
        self._statement_override = None
        self._render()

    def _current(self) -> dict | None:
        if not self._items:
            return None
        return self._items[self._idx]

    def _render(self) -> None:
        status = self.query_one("#status", Static)
        body = self.query_one("#body", Static)

        if not self._items:
            status.update("[b]Review queue empty[/b]")
            body.update("Nothing pending. Run `nxc mine research extract` to populate.")
            return

        item = self._items[self._idx]
        payload = item["payload"]
        extracted = payload.get("extracted", {})
        paper = _fetch_paper(item["source_paper_id"]) if item["source_paper_id"] else None
        candidates = payload.get("candidates", [])
        statement_now = self._statement_override or extracted.get("canonical_statement", "")

        status.update(
            f"[b]Item {self._idx + 1} / {len(self._items)}[/b]  "
            f"queue#{item['id']}  •  kind={item['kind']}  •  "
            f"paper#{item['source_paper_id']}  •  "
            f"pending={store.count_review_queue()}"
        )

        lines: list[str] = []
        if paper:
            lines.append(f"[dim]paper[/dim]  [{paper['source']}:{paper['ext_id']}]  {paper['title']}")
        else:
            lines.append("[dim]paper[/dim]  (no associated paper)")
        edited = " [yellow](edited)[/yellow]" if self._statement_override else ""
        lines.append(f"\n[bold cyan]NEW[/bold cyan]{edited}: {statement_now}")
        lines.append(
            f"[dim]type[/dim]={extracted.get('problem_type','?')}  "
            f"[dim]role[/dim]={extracted.get('role','?')}  "
            f"[dim]conf[/dim]={extracted.get('confidence','?')}"
        )
        evidence = (extracted.get("evidence") or "").strip()
        if evidence:
            lines.append(f"[dim]evidence[/dim]: {evidence}")
        if candidates:
            lines.append("\n[dim]Closest existing:[/dim]")
            for c in candidates[:5]:
                p = _fetch_problem(c["id"])
                stmt = p["canonical_statement"] if p else "(missing)"
                lines.append(
                    f"  [bold]#{c['id']}[/bold]  sim={c['sim']:.3f}  {stmt}"
                )
        body.update("\n".join(lines))

    # ─── actions ───

    def _best_target(self) -> int | None:
        item = self._current()
        if not item:
            return None
        cands = item["payload"].get("candidates") or []
        return cands[0]["id"] if cands else None

    def _statement(self) -> str:
        item = self._current()
        if not item:
            return ""
        return self._statement_override or item["payload"].get("extracted", {}).get("canonical_statement", "")

    def _apply(self, decision: str, target_id: int | None = None) -> None:
        item = self._current()
        if not item:
            self.bell()
            return
        try:
            note = apply_review_decision(
                item, decision, target_id=target_id,
                new_statement=self._statement_override,
            )
        except Exception as e:  # noqa: BLE001
            self.notify(f"failed: {e}", severity="error", timeout=5)
            return
        self.notify(note, severity="information", timeout=3)
        # Drop the resolved item and stay on the same index (next item slides in).
        del self._items[self._idx]
        self._statement_override = None
        if self._idx >= len(self._items):
            self._idx = max(0, len(self._items) - 1)
        self._render()

    def action_accept(self) -> None:        self._apply("accept_new")
    def action_reject(self) -> None:        self._apply("reject")

    def action_merge(self) -> None:
        t = self._best_target()
        if t is None:
            self.notify("no candidate target to merge into", severity="warning"); return
        self._apply("merge", target_id=t)

    def action_specialize(self) -> None:
        t = self._best_target()
        if t is None:
            self.notify("no candidate target to specialize", severity="warning"); return
        self._apply("specialize", target_id=t)

    def action_related(self) -> None:
        t = self._best_target()
        if t is None:
            self.notify("no candidate target to relate to", severity="warning"); return
        self._apply("related", target_id=t)

    def action_next(self) -> None:
        if not self._items:
            return
        self._idx = (self._idx + 1) % len(self._items)
        self._statement_override = None
        self._render()

    def action_prev(self) -> None:
        if not self._items:
            return
        self._idx = (self._idx - 1) % len(self._items)
        self._statement_override = None
        self._render()

    def action_edit(self) -> None:
        item = self._current()
        if not item:
            return
        current = self._statement()

        def _got(new: str | None) -> None:
            if new is not None and new.strip() and new != current:
                self._statement_override = new.strip()
                self.notify("statement edited; choose action to commit", timeout=3)
                self._render()

        self.push_screen(EditStatementScreen(current), _got)


def run() -> int:
    ReviewApp().run()
    return 0
