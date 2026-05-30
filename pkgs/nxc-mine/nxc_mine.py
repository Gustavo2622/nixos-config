#!/usr/bin/env python3
"""nxc-mine — research/content mining framework for nxc.

`nxc mine research <init|ingest|embed|extract|papers|problems|assumptions|review>`.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import sys
from typing import Iterable

import config
import dedup as dedup_mod
import extract as extract_mod
import ollama
import store


# ─── research subcommand ────────────────────────────────────────────────────


def _cmd_research_init(_: argparse.Namespace) -> int:
    store.init_schema()
    print("Schema applied (papers, problems, assumptions, edges, review_queue).")
    return 0


def _cmd_research_ingest(args: argparse.Namespace) -> int:
    since = dt.date.today() - dt.timedelta(days=args.window)
    sources = args.sources or ["arxiv", "eprint"]
    total_found = total_new = total_upd = total_err = 0

    for source in sources:
        for category, conf in config.CATEGORIES.items():
            if args.category and category != args.category:
                continue
            run = store.start_ingest_run(source, category)
            print(f"[{source}/{category}] ingesting since {since}…", flush=True)
            try:
                if source == "arxiv":
                    from sources import arxiv
                    papers, errs = arxiv.fetch(
                        categories=conf["arxiv"]["categories"],
                        since=since,
                        our_category=category,
                    )
                elif source == "eprint":
                    ep = conf.get("eprint", {})
                    if not ep.get("enabled", False):
                        store.finish_ingest_run(run.id, found=0, new=0, updated=0,
                                                errors=0, notes="eprint disabled for this category")
                        continue
                    from sources import eprint
                    papers, errs = eprint.fetch(
                        since=since,
                        areas=ep.get("areas") or None,
                        our_category=category,
                    )
                else:
                    print(f"  unknown source: {source}", file=sys.stderr)
                    store.finish_ingest_run(run.id, found=0, new=0, updated=0,
                                            errors=1, notes="unknown source")
                    total_err += 1
                    continue
                new, upd = store.upsert_papers(papers)
                store.finish_ingest_run(run.id, found=len(papers), new=new,
                                        updated=upd, errors=errs)
                total_found += len(papers); total_new += new
                total_upd += upd; total_err += errs
                print(f"  found={len(papers)} new={new} revised={upd} errors={errs}")
            except Exception as e:  # noqa: BLE001
                store.finish_ingest_run(run.id, found=0, new=0, updated=0, errors=1,
                                        notes=f"{type(e).__name__}: {e}")
                total_err += 1
                print(f"  FAILED: {type(e).__name__}: {e}", file=sys.stderr)

    print()
    print(f"Total: found={total_found} new={total_new} revised={total_upd} errors={total_err}")
    print(f"Papers in DB: {store.count_papers()}")
    return 1 if total_err and total_found == 0 else 0


def _cmd_research_embed(args: argparse.Namespace) -> int:
    """Compute and store paper-level embeddings (title + abstract) for papers
    that don't have one yet. Done in batches to amortize HTTP overhead.

    `--reembed` wipes all existing paper embeddings first — use when changing
    the embed model so old vectors aren't mixed with new (they'd be
    incomparable).
    """
    if args.reembed:
        n = store.clear_paper_embeddings()
        print(f"Cleared {n} existing embeddings.")
    total_done = 0
    batch_size = max(1, args.batch)
    while True:
        rows = store.papers_needing_embedding(limit=batch_size)
        if not rows:
            break
        texts = [f"{r['title']}\n\n{r['abstract']}" for r in rows]
        vecs = ollama.embed(texts)
        if len(vecs) != len(rows):
            print(f"WARNING: requested {len(rows)} embeddings, got {len(vecs)}", file=sys.stderr)
        for r, v in zip(rows, vecs):
            store.set_paper_embedding(r["id"], v)
            total_done += 1
        print(f"  embedded {total_done} papers", flush=True)
        if args.limit and total_done >= args.limit:
            break
    print(f"Done. {total_done} papers embedded.")
    return 0


def _cmd_research_extract(args: argparse.Namespace) -> int:
    """Pull problems + assumptions from each paper's abstract; dedup as we go.

    Concurrency model: the slow `extract_from_abstract` LLM call runs in a
    ThreadPoolExecutor (`concurrency` workers). Dedup decisions and DB writes
    stay on the main thread — keeping them serial avoids merge races where
    two papers concurrently insert near-duplicate problems before either is
    visible to the other.
    """
    from concurrent.futures import ThreadPoolExecutor, as_completed

    dedup_top_k = config.dedup_cfg()["top_k"]
    concurrency = max(1, args.concurrency or config.extract_cfg()["concurrency"])

    papers = store.papers_needing_extraction(limit=args.limit)
    if not papers:
        print("No papers need extraction.")
        return 0

    print(f"Extracting from {len(papers)} papers (concurrency={concurrency})…", flush=True)
    counts = {"problems_new": 0, "problems_merged": 0, "problems_queued": 0,
              "assumptions": 0, "papers_failed": 0, "papers_done": 0}

    def _extract_one(paper: dict) -> tuple[dict, dict | None, Exception | None]:
        try:
            res = extract_mod.extract_from_abstract(paper["title"], paper["abstract"])
            return (paper, res, None)
        except Exception as e:  # noqa: BLE001 — surface to main thread
            return (paper, None, e)

    with ThreadPoolExecutor(max_workers=concurrency) as ex:
        futures = [ex.submit(_extract_one, p) for p in papers]
        for fut in as_completed(futures):
            paper, result, err = fut.result()
            if err is not None or result is None:
                counts["papers_failed"] += 1
                print(f"  [{paper['id']}] FAILED extract: "
                      f"{type(err).__name__ if err else 'NoneResult'}: {err}",
                      file=sys.stderr)
                continue
            crypto_ok = bool(result.get("crypto_relevant", False))
            reason = (result.get("relevance_reason") or "").strip() or None
            if crypto_ok:
                for prob in result.get("problems", []):
                    _handle_problem(paper, prob, dedup_top_k, counts)
                for asm in result.get("assumptions", []):
                    _handle_assumption(paper, asm, counts)
            else:
                counts["papers_filtered"] = counts.get("papers_filtered", 0) + 1
            store.mark_paper_extracted(paper["id"],
                                       crypto_relevant=crypto_ok,
                                       relevance_reason=reason)
            counts["papers_done"] += 1
            marker = "" if crypto_ok else " [filtered: non-crypto]"
            print(f"  [{paper['id']}] p={len(result['problems'])} "
                  f"a={len(result['assumptions'])}{marker} "
                  f"({counts['papers_done']}/{len(papers)})", flush=True)

    print()
    print(f"Done. problems: new={counts['problems_new']} "
          f"merged={counts['problems_merged']} queued={counts['problems_queued']} | "
          f"assumption-edges={counts['assumptions']} | "
          f"papers_filtered={counts.get('papers_filtered', 0)} | "
          f"papers_failed={counts['papers_failed']}")
    print(f"Pending review queue: {store.count_review_queue()}")
    return 0


def _handle_problem(paper: dict, prob: dict, top_k: int, counts: dict) -> None:
    statement = (prob.get("canonical_statement") or "").strip()
    if not statement:
        return  # nothing to embed/dedup
    try:
        vec = ollama.embed(statement)[0] or []
    except Exception as e:  # noqa: BLE001
        print(f"  [{paper['id']}] embed problem failed: {e}", file=sys.stderr)
        return
    if not vec:
        print(f"  [{paper['id']}] empty embedding for problem; skipping", file=sys.stderr)
        return

    candidates = store.retrieve_similar_problems(
        vec, category=paper["category"], top_k=top_k,
    )

    try:
        d = dedup_mod.decide(statement, candidates)
    except Exception as e:  # noqa: BLE001
        # If the judge call fails, fall back to queueing so nothing is lost.
        print(f"  [{paper['id']}] judge failed, queueing: {e}", file=sys.stderr)
        store.enqueue_review(kind="new_problem",
                            payload={"extracted": prob, "judge_error": str(e),
                                     "candidates": [{"id": c, "sim": s}
                                                    for (c, s) in [(cid, sim) for (cid, _, sim) in candidates]]},
                            source_paper_id=paper["id"])
        counts["problems_queued"] += 1
        return

    role       = prob["role"]
    confidence = float(prob["confidence"])
    evidence   = prob.get("evidence")

    if d.decision == "accept_new":
        new_id = store.insert_problem(
            canonical_statement=statement,
            problem_type=prob["problem_type"],
            category=paper["category"],
            embedding=vec,
        )
        store.add_paper_problem_edge(paper["id"], new_id, role=role,
                                    confidence=confidence, evidence=evidence)
        counts["problems_new"] += 1

    elif d.decision == "merge_into":
        store.add_problem_alias(d.target_id, statement)
        store.add_paper_problem_edge(paper["id"], d.target_id, role=role,
                                    confidence=confidence, evidence=evidence)
        counts["problems_merged"] += 1

    elif d.decision in ("specialize_of", "related_to"):
        new_id = store.insert_problem(
            canonical_statement=statement,
            problem_type=prob["problem_type"],
            category=paper["category"],
            embedding=vec,
        )
        kind = "specializes" if d.decision == "specialize_of" else "related"
        store.add_problem_problem_edge(parent_id=d.target_id, child_id=new_id, kind=kind)
        store.add_paper_problem_edge(paper["id"], new_id, role=role,
                                    confidence=confidence, evidence=evidence)
        counts["problems_new"] += 1

    elif d.decision == "queue":
        store.enqueue_review(
            kind="new_problem",
            payload={
                "extracted": prob,
                "candidates": [{"id": cid, "sim": sim} for (cid, sim) in d.candidates],
                "best_target_id": d.target_id,
                "best_score": d.target_score,
            },
            source_paper_id=paper["id"],
        )
        counts["problems_queued"] += 1


def _handle_assumption(paper: dict, asm: dict, counts: dict) -> None:
    """Canonical-named assumptions UPSERT by canonical_name. Novel assumptions
    (model-flagged with is_novel=true) go to the review queue rather than
    auto-merging — protects the assumptions table from junk names like
    'depolarizing noise' or 'Bell inequalities'."""
    name = (asm.get("canonical_name") or "").strip()
    if not name:
        return
    statement = (asm.get("statement") or "").strip()

    # Treat denylisted names (ciphers/primitives/areas/attack-models the
    # model misclassifies as assumptions) as if they were novel — let the
    # human decide rather than polluting the assumptions table.
    if asm.get("is_novel") or config.is_denylisted_assumption(name):
        store.enqueue_review(
            kind="new_assumption",
            payload={
                "extracted": asm,
                "paper_id": paper["id"],
                "denylisted": (not asm.get("is_novel")) and config.is_denylisted_assumption(name),
            },
            source_paper_id=paper["id"],
        )
        counts["assumptions_queued"] = counts.get("assumptions_queued", 0) + 1
        return

    vec: list[float] | None = None
    if statement:
        try:
            vec = ollama.embed(statement)[0] or None
        except Exception:
            vec = None
    aid = store.upsert_assumption(
        canonical_name=name,
        statement=statement or name,
        category=paper["category"],
        embedding=vec,
    )
    store.add_paper_assumption_edge(
        paper["id"], aid,
        role=asm["role"],
        parameters=(asm.get("parameters") or None),
        confidence=float(asm["confidence"]),
        evidence=asm.get("evidence"),
    )
    counts["assumptions"] += 1


def _cmd_research_papers(args: argparse.Namespace) -> int:
    rows = store.list_papers(
        category=args.category, source=args.source,
        search=args.search, only_new=args.only_new,
        only_revised=args.only_revised, non_crypto=args.non_crypto,
        limit=args.limit,
    )
    if not rows:
        print("(no papers match)")
        return 0
    for r in rows:
        fp = r["first_published"]; lr = r["last_revised"]
        marker = "" if fp == lr else " ↺"
        authors = ", ".join(r["authors"][:3])
        if len(r["authors"]) > 3:
            authors += f" + {len(r['authors']) - 3} more"
        print(f"[{r['source']}:{r['ext_id']}] {lr}{marker}  {r['title']}")
        print(f"    {authors}")
        if r["source_categories"]:
            print(f"    tags: {', '.join(r['source_categories'])}")
        if args.non_crypto and r.get("relevance_reason"):
            print(f"    reason: {r['relevance_reason']}")
    print()
    print(f"({len(rows)} shown)")
    return 0


def _cmd_research_reset(args: argparse.Namespace) -> int:
    """Clear extracted_at + gate columns + paper_problem / paper_assumption
    edges so the next `extract` reprocesses these papers."""
    if not (args.all or args.sample or args.ids):
        print("specify one of --all / --sample N / --ids ID,ID,...", file=sys.stderr)
        return 2
    ids = None
    if args.ids:
        try:
            ids = [int(x) for x in args.ids.split(",") if x.strip()]
        except ValueError:
            print("--ids must be a comma-separated list of integers", file=sys.stderr)
            return 2
    if args.purge and not args.all:
        print("--purge only valid with --all (drops all problems/assumptions/queue).", file=sys.stderr)
        return 2
    n = store.reset_extraction(ids=ids, sample=args.sample, all_=args.all, purge=args.purge)
    if args.purge:
        print(f"Reset extraction state for {n} papers AND purged all "
              "problems/assumptions/edges/review_queue.")
    else:
        print(f"Reset extraction state for {n} papers.")
    return 0


def _cmd_research_problems(args: argparse.Namespace) -> int:
    rows = store.list_problems(category=args.category, status=args.status, limit=args.limit)
    if not rows:
        print("(no problems yet — run `nxc mine research extract`)")
        return 0
    for r in rows:
        parent = f" (specialization of #{r['parent_id']})" if r["parent_id"] else ""
        print(f"#{r['id']}  [{r['problem_type']} / {r['status']} / {r['category']}]{parent}")
        print(f"    {r['canonical_statement']}")
    print()
    print(f"({len(rows)} shown)")
    return 0


def _cmd_research_assumptions(args: argparse.Namespace) -> int:
    rows = store.list_assumptions(category=args.category, limit=args.limit)
    if not rows:
        print("(no assumptions yet — run `nxc mine research extract`)")
        return 0
    for r in rows:
        print(f"#{r['id']}  {r['canonical_name']}  [{r['category']}]")
        print(f"    {r['statement']}")
    print()
    print(f"({len(rows)} shown)")
    return 0


def _cmd_research_review(args: argparse.Namespace) -> int:
    if args.json:
        rows = store.list_review_queue(status="pending", limit=args.limit)
        out = []
        for r in rows:
            r2 = dict(r)
            for k, v in list(r2.items()):
                if isinstance(v, (dt.datetime, dt.date)):
                    r2[k] = v.isoformat()
            out.append(r2)
        print(json.dumps(out, indent=2))
        return 0
    # Interactive TUI by default.
    import tui
    return tui.run()


# ─── dispatcher ─────────────────────────────────────────────────────────────


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="nxc-mine", description=__doc__.splitlines()[0])
    sub = p.add_subparsers(dest="domain", required=True, metavar="<domain>")

    research = sub.add_parser("research", help="Research-paper mining")
    rsub = research.add_subparsers(dest="cmd", required=True, metavar="<cmd>")

    init = rsub.add_parser("init", help="Apply schema (idempotent)")
    init.set_defaults(func=_cmd_research_init)

    ing = rsub.add_parser("ingest", help="Pull recent papers into the DB")
    ing.add_argument("--source", action="append", dest="sources",
                     choices=["arxiv", "eprint"])
    ing.add_argument("--category", choices=list(config.CATEGORIES.keys()))
    ing.add_argument("--window", type=int, default=config.DEFAULT_WINDOW_DAYS)
    ing.set_defaults(func=_cmd_research_ingest)

    emb = rsub.add_parser("embed", help="Compute paper-level embeddings")
    emb.add_argument("--batch", type=int, default=32,
                     help="Papers per Ollama call (default 32)")
    emb.add_argument("--limit", type=int, default=0,
                     help="Stop after N papers (0 = no limit)")
    emb.add_argument("--reembed", action="store_true",
                     help="Wipe all existing paper embeddings first (use when changing embed model)")
    emb.set_defaults(func=_cmd_research_embed)

    ext = rsub.add_parser("extract", help="Extract problems + assumptions from abstracts")
    ext.add_argument("--limit", type=int, default=20,
                     help="Max papers to process this run (default 20; abstracts are small "
                          "but each paper triggers ≥1 LLM call)")
    ext.add_argument("--concurrency", type=int, default=0,
                     help="Concurrent extract calls to Ollama (0 = use config.toml default)")
    ext.set_defaults(func=_cmd_research_extract)

    pap = rsub.add_parser("papers", help="List papers in the DB")
    pap.add_argument("--category"); pap.add_argument("--source")
    pap.add_argument("--search")
    pap.add_argument("--only-new", action="store_true")
    pap.add_argument("--only-revised", action="store_true")
    pap.add_argument("--non-crypto", action="store_true",
                     help="Only papers the crypto-relevance gate filtered out")
    pap.add_argument("--limit", type=int, default=50)
    pap.set_defaults(func=_cmd_research_papers)

    rst = rsub.add_parser("reset", help="Wipe extraction state for selected papers (sample/all/ids)")
    rst.add_argument("--sample", type=int,
                     help="Pick N random already-extracted papers and reset them")
    rst.add_argument("--ids", help="Comma-separated paper IDs to reset")
    rst.add_argument("--all", action="store_true",
                     help="Reset every extracted paper (destructive — use with care)")
    rst.add_argument("--purge", action="store_true",
                     help="With --all: also TRUNCATE problems/assumptions/edges/review_queue. "
                          "Clean slate when changing the extract prompt.")
    rst.set_defaults(func=_cmd_research_reset)

    prob = rsub.add_parser("problems", help="List extracted problems")
    prob.add_argument("--category"); prob.add_argument("--status")
    prob.add_argument("--limit", type=int, default=50)
    prob.set_defaults(func=_cmd_research_problems)

    asm = rsub.add_parser("assumptions", help="List extracted assumptions")
    asm.add_argument("--category"); asm.add_argument("--limit", type=int, default=50)
    asm.set_defaults(func=_cmd_research_assumptions)

    rev = rsub.add_parser("review", help="Interactive review queue (Textual TUI; --json for dump)")
    rev.add_argument("--limit", type=int, default=500,
                     help="Items to load (TUI shows them sequentially)")
    rev.add_argument("--json", action="store_true",
                     help="Skip the TUI and emit pending payloads as JSON")
    rev.set_defaults(func=_cmd_research_review)

    return p


def main(argv: Iterable[str] | None = None) -> int:
    args = build_parser().parse_args(list(argv) if argv is not None else None)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
