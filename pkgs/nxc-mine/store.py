"""Postgres helpers: connection, schema init, paper upserts, problems/assumptions,
embeddings, dedup retrieval, review queue.

We deliberately avoid the pgvector-python type adapter — fewer moving parts.
Embeddings get rendered to a `'[v1, v2, …]'::vector(1024)` literal at write
time and parsed back via psycopg's default text decoding.
"""

from __future__ import annotations

import datetime as dt
import json
import pathlib
from contextlib import contextmanager
from dataclasses import dataclass
from typing import Iterable, Iterator

import psycopg
from psycopg.rows import dict_row

from config import DB_DSN

_SCHEMA_PATH = pathlib.Path(__file__).parent / "schema.sql"


@dataclass
class Paper:
    source: str
    ext_id: str
    title: str
    authors: list[str]
    first_published: dt.date | None
    last_revised: dt.date | None
    latest_version: str | None
    category: str
    source_categories: list[str]
    abstract: str | None
    pdf_url: str | None


@contextmanager
def connect() -> Iterator[psycopg.Connection]:
    with psycopg.connect(DB_DSN, row_factory=dict_row) as conn:
        yield conn


def init_schema() -> None:
    sql = _SCHEMA_PATH.read_text()
    with connect() as conn:
        with conn.cursor() as cur:
            cur.execute(sql)
        conn.commit()


# ─── ingest (unchanged from slice 2a — papers + ingest_runs) ───────────────


def upsert_papers(papers: Iterable[Paper]) -> tuple[int, int]:
    new_count = 0
    upd_count = 0
    rows = list(papers)
    if not rows:
        return (0, 0)
    with connect() as conn:
        with conn.cursor() as cur:
            for p in rows:
                cur.execute(
                    """
                    INSERT INTO papers (source, ext_id, title, authors,
                                        first_published, last_revised, latest_version,
                                        category, source_categories, abstract, pdf_url)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    ON CONFLICT (source, ext_id) DO UPDATE SET
                        title = EXCLUDED.title,
                        authors = EXCLUDED.authors,
                        last_revised = GREATEST(papers.last_revised, EXCLUDED.last_revised),
                        latest_version = COALESCE(EXCLUDED.latest_version, papers.latest_version),
                        source_categories = EXCLUDED.source_categories,
                        abstract = EXCLUDED.abstract,
                        pdf_url = EXCLUDED.pdf_url
                      WHERE EXCLUDED.last_revised IS DISTINCT FROM papers.last_revised
                         OR EXCLUDED.latest_version IS DISTINCT FROM papers.latest_version
                         OR EXCLUDED.title IS DISTINCT FROM papers.title
                    RETURNING (xmax = 0) AS inserted
                    """,
                    (
                        p.source, p.ext_id, p.title, p.authors,
                        p.first_published, p.last_revised, p.latest_version,
                        p.category, p.source_categories, p.abstract, p.pdf_url,
                    ),
                )
                row = cur.fetchone()
                if row is None:
                    continue
                if row["inserted"]:
                    new_count += 1
                else:
                    upd_count += 1
        conn.commit()
    return (new_count, upd_count)


@dataclass
class IngestRun:
    id: int
    source: str
    category: str
    started_at: dt.datetime


def start_ingest_run(source: str, category: str) -> IngestRun:
    with connect() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """INSERT INTO ingest_runs (source, category, started_at)
                   VALUES (%s, %s, NOW())
                   RETURNING id, source, category, started_at""",
                (source, category),
            )
            row = cur.fetchone()
        conn.commit()
    return IngestRun(**row)


def finish_ingest_run(run_id: int, *, found: int, new: int, updated: int,
                     errors: int = 0, notes: str | None = None) -> None:
    with connect() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """UPDATE ingest_runs
                      SET finished_at = NOW(),
                          papers_found = %s, papers_new = %s,
                          papers_updated = %s, errors = %s, notes = %s
                    WHERE id = %s""",
                (found, new, updated, errors, notes, run_id),
            )
        conn.commit()


def list_papers(*, category: str | None = None, source: str | None = None,
                search: str | None = None, only_new: bool = False,
                only_revised: bool = False, non_crypto: bool = False,
                limit: int = 50) -> list[dict]:
    sql = ("SELECT id, source, ext_id, title, authors, first_published, last_revised, "
           "latest_version, category, source_categories, pdf_url, "
           "crypto_relevant, relevance_reason FROM papers")
    where, args = [], []
    if category:
        where.append("category = %s"); args.append(category)
    if source:
        where.append("source = %s"); args.append(source)
    if search:
        where.append("(title ILIKE %s OR abstract ILIKE %s)")
        args.extend([f"%{search}%", f"%{search}%"])
    if only_new:
        where.append("last_revised IS NOT DISTINCT FROM first_published")
    if only_revised:
        where.append("last_revised > first_published")
    if non_crypto:
        where.append("crypto_relevant = FALSE")
    if where:
        sql += " WHERE " + " AND ".join(where)
    sql += " ORDER BY COALESCE(last_revised, first_published) DESC NULLS LAST, id DESC LIMIT %s"
    args.append(limit)
    with connect() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, args)
            return list(cur.fetchall())


def count_papers() -> int:
    with connect() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT COUNT(*) AS n FROM papers")
            r = cur.fetchone()
            return int(r["n"]) if r else 0


# ─── embeddings ────────────────────────────────────────────────────────────


def _vec_literal(values: list[float] | None) -> str | None:
    """Render a python list as a pgvector input literal. Returns None for
    falsy inputs (empty list / None) — callers persist that as SQL NULL."""
    if not values:
        return None
    return "[" + ",".join(repr(float(v)) for v in values) + "]"


def papers_needing_embedding(limit: int = 200) -> list[dict]:
    with connect() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """SELECT id, title, abstract FROM papers
                    WHERE embedded_at IS NULL AND abstract IS NOT NULL
                    ORDER BY id
                    LIMIT %s""",
                (limit,),
            )
            return list(cur.fetchall())


def clear_paper_embeddings() -> int:
    """Wipe all paper embeddings (used when switching embed model). Returns
    the number of rows reset."""
    with connect() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """UPDATE papers SET embedding = NULL, embedded_at = NULL
                    WHERE embedded_at IS NOT NULL"""
            )
            n = cur.rowcount
        conn.commit()
    return n


def set_paper_embedding(paper_id: int, embedding: list[float]) -> None:
    lit = _vec_literal(embedding)
    with connect() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "UPDATE papers SET embedding = %s::vector, embedded_at = NOW() WHERE id = %s",
                (lit, paper_id),
            )
        conn.commit()


def papers_needing_extraction(limit: int = 100) -> list[dict]:
    with connect() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """SELECT id, title, abstract, category, is_preprint
                     FROM papers
                    WHERE extracted_at IS NULL
                      AND abstract IS NOT NULL
                    ORDER BY id
                    LIMIT %s""",
                (limit,),
            )
            return list(cur.fetchall())


def mark_paper_extracted(
    paper_id: int,
    *,
    crypto_relevant: bool | None = None,
    relevance_reason: str | None = None,
) -> None:
    with connect() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """UPDATE papers
                      SET extracted_at = NOW(),
                          crypto_relevant = COALESCE(%s, crypto_relevant),
                          relevance_reason = COALESCE(%s, relevance_reason)
                    WHERE id = %s""",
                (crypto_relevant, relevance_reason, paper_id),
            )
        conn.commit()


def reset_extraction(
    *,
    ids: list[int] | None = None,
    sample: int | None = None,
    all_: bool = False,
    purge: bool = False,
) -> int:
    """Wipe extracted_at + crypto_relevant + relevance_reason and the paper's
    paper_problem / paper_assumption edges, so the next `extract` reprocesses
    them.

    `purge=True` (only valid with `all_=True`) also TRUNCATEs the derived
    tables — problems, assumptions, problem_problem, review_queue, and all
    edges — leaving a clean slate. Use when changing the extract prompt to
    avoid orphaned rows from prior runs.

    Returns the number of papers reset.
    """
    with connect() as conn:
        with conn.cursor() as cur:
            if all_ and purge:
                cur.execute("SELECT COUNT(*)::int AS n FROM papers WHERE extracted_at IS NOT NULL")
                target_n = cur.fetchone()["n"]
                cur.execute(
                    "TRUNCATE paper_problem, paper_assumption, problem_problem, "
                    "review_queue, problems, assumptions RESTART IDENTITY CASCADE"
                )
                cur.execute(
                    """UPDATE papers
                          SET extracted_at = NULL,
                              crypto_relevant = NULL,
                              relevance_reason = NULL
                        WHERE extracted_at IS NOT NULL"""
                )
                conn.commit()
                return target_n

            # Non-purge path: per-paper selection
            if all_:
                cur.execute("SELECT id FROM papers WHERE extracted_at IS NOT NULL")
                target = [r["id"] for r in cur.fetchall()]
            elif ids:
                target = list(ids)
            elif sample:
                cur.execute(
                    """SELECT id FROM papers
                        WHERE extracted_at IS NOT NULL
                        ORDER BY random()
                        LIMIT %s""",
                    (sample,),
                )
                target = [r["id"] for r in cur.fetchall()]
            else:
                return 0
            if not target:
                return 0
            cur.execute("DELETE FROM paper_problem    WHERE paper_id = ANY(%s)", (target,))
            cur.execute("DELETE FROM paper_assumption WHERE paper_id = ANY(%s)", (target,))
            cur.execute(
                """UPDATE papers
                      SET extracted_at = NULL,
                          crypto_relevant = NULL,
                          relevance_reason = NULL
                    WHERE id = ANY(%s)""",
                (target,),
            )
        conn.commit()
    return len(target)


# ─── problems / assumptions ────────────────────────────────────────────────


def insert_problem(*, canonical_statement: str, problem_type: str,
                  category: str, embedding: list[float] | None) -> int:
    emb_lit = _vec_literal(embedding) if embedding is not None else None
    with connect() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """INSERT INTO problems (canonical_statement, problem_type, category, embedding)
                   VALUES (%s, %s, %s, %s::vector)
                   RETURNING id""",
                (canonical_statement, problem_type, category, emb_lit),
            )
            rid = cur.fetchone()["id"]
        conn.commit()
    return rid


def add_problem_alias(problem_id: int, alias: str) -> None:
    """Append `alias` if not already present."""
    with connect() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """UPDATE problems
                      SET aliases = ARRAY(SELECT DISTINCT unnest(aliases || ARRAY[%s])),
                          updated_at = NOW()
                    WHERE id = %s""",
                (alias, problem_id),
            )
        conn.commit()


def upsert_assumption(*, canonical_name: str, statement: str,
                     category: str, embedding: list[float] | None) -> int:
    """Assumptions are keyed by canonical_name (UNIQUE) — second appearance of
    'LWE' updates the existing row rather than creating a new one."""
    emb_lit = _vec_literal(embedding) if embedding is not None else None
    with connect() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """INSERT INTO assumptions (canonical_name, statement, category, embedding)
                   VALUES (%s, %s, %s, %s::vector)
                   ON CONFLICT (canonical_name) DO UPDATE
                     SET statement = EXCLUDED.statement,
                         updated_at = NOW()
                   RETURNING id""",
                (canonical_name, statement, category, emb_lit),
            )
            rid = cur.fetchone()["id"]
        conn.commit()
    return rid


def add_paper_problem_edge(paper_id: int, problem_id: int, *,
                          role: str, confidence: float, evidence: str | None) -> None:
    with connect() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """INSERT INTO paper_problem (paper_id, problem_id, role, confidence, evidence)
                   VALUES (%s, %s, %s, %s, %s)
                   ON CONFLICT (paper_id, problem_id, role) DO UPDATE
                     SET confidence = GREATEST(paper_problem.confidence, EXCLUDED.confidence),
                         evidence = COALESCE(EXCLUDED.evidence, paper_problem.evidence)""",
                (paper_id, problem_id, role, confidence, evidence),
            )
        conn.commit()


def add_paper_assumption_edge(paper_id: int, assumption_id: int, *,
                             role: str, parameters: str | None,
                             confidence: float, evidence: str | None) -> None:
    with connect() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """INSERT INTO paper_assumption
                       (paper_id, assumption_id, role, parameters, confidence, evidence)
                   VALUES (%s, %s, %s, %s, %s, %s)
                   ON CONFLICT (paper_id, assumption_id, role) DO UPDATE
                     SET parameters = COALESCE(EXCLUDED.parameters, paper_assumption.parameters),
                         confidence = GREATEST(paper_assumption.confidence, EXCLUDED.confidence),
                         evidence = COALESCE(EXCLUDED.evidence, paper_assumption.evidence)""",
                (paper_id, assumption_id, role, parameters, confidence, evidence),
            )
        conn.commit()


def add_problem_problem_edge(parent_id: int, child_id: int, kind: str) -> None:
    if parent_id == child_id:
        return
    with connect() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """INSERT INTO problem_problem (parent_id, child_id, kind)
                   VALUES (%s, %s, %s)
                   ON CONFLICT DO NOTHING""",
                (parent_id, child_id, kind),
            )
        conn.commit()


# ─── dedup retrieval ───────────────────────────────────────────────────────


def retrieve_similar_problems(embedding: list[float], *, category: str | None,
                             top_k: int) -> list[tuple[int, str, float]]:
    """Return [(id, canonical_statement, similarity)] sorted by similarity desc.

    pgvector's `<=>` is cosine *distance*; convert to similarity = 1 - distance.
    """
    lit = _vec_literal(embedding)
    args: list = [lit]
    where = "WHERE embedding IS NOT NULL"
    if category:
        where += " AND category = %s"
        args.append(category)
    args.append(top_k)
    with connect() as conn:
        with conn.cursor() as cur:
            cur.execute(
                f"""SELECT id, canonical_statement,
                          1 - (embedding <=> %s::vector) AS similarity
                     FROM problems
                     {where}
                     ORDER BY embedding <=> %s::vector
                     LIMIT %s""",
                (args[0], *args[1:-1], args[0], args[-1]),
            )
            return [(r["id"], r["canonical_statement"], float(r["similarity"]))
                    for r in cur.fetchall()]


def retrieve_similar_assumptions(embedding: list[float], *,
                                top_k: int) -> list[tuple[int, str, float]]:
    lit = _vec_literal(embedding)
    with connect() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """SELECT id, canonical_name,
                          1 - (embedding <=> %s::vector) AS similarity
                     FROM assumptions
                    WHERE embedding IS NOT NULL
                    ORDER BY embedding <=> %s::vector
                    LIMIT %s""",
                (lit, lit, top_k),
            )
            return [(r["id"], r["canonical_name"], float(r["similarity"]))
                    for r in cur.fetchall()]


# ─── review queue ──────────────────────────────────────────────────────────


def enqueue_review(*, kind: str, payload: dict,
                  source_paper_id: int | None) -> int:
    with connect() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """INSERT INTO review_queue (kind, payload, source_paper_id)
                   VALUES (%s, %s, %s) RETURNING id""",
                (kind, json.dumps(payload), source_paper_id),
            )
            rid = cur.fetchone()["id"]
        conn.commit()
    return rid


def list_review_queue(status: str = "pending", limit: int = 50) -> list[dict]:
    with connect() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """SELECT id, kind, payload, source_paper_id, status, created_at, resolved_at
                     FROM review_queue
                    WHERE status = %s
                    ORDER BY created_at ASC, id ASC
                    LIMIT %s""",
                (status, limit),
            )
            return list(cur.fetchall())


def count_review_queue(status: str = "pending") -> int:
    with connect() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT COUNT(*) AS n FROM review_queue WHERE status = %s", (status,))
            r = cur.fetchone()
            return int(r["n"]) if r else 0


# ─── browse: problems / assumptions ────────────────────────────────────────


def list_problems(*, category: str | None = None, status: str | None = None,
                 limit: int = 50) -> list[dict]:
    sql = "SELECT id, canonical_statement, problem_type, status, category, parent_id FROM problems"
    where, args = [], []
    if category:
        where.append("category = %s"); args.append(category)
    if status:
        where.append("status = %s"); args.append(status)
    if where:
        sql += " WHERE " + " AND ".join(where)
    sql += " ORDER BY updated_at DESC LIMIT %s"
    args.append(limit)
    with connect() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, args)
            return list(cur.fetchall())


def all_assumption_names() -> list[tuple[int, str]]:
    """Return [(id, canonical_name)] over the whole table — used by the
    cleanup command which applies config.is_denylisted_assumption()."""
    with connect() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT id, canonical_name FROM assumptions ORDER BY id")
            return [(r["id"], r["canonical_name"]) for r in cur.fetchall()]


def delete_assumptions(ids: list[int]) -> tuple[int, int]:
    """Delete the assumption rows + their paper edges. Returns (edges, rows)."""
    if not ids:
        return (0, 0)
    with connect() as conn:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM paper_assumption WHERE assumption_id = ANY(%s)", (ids,))
            edges = cur.rowcount
            cur.execute("DELETE FROM assumptions WHERE id = ANY(%s)", (ids,))
            rows = cur.rowcount
        conn.commit()
    return (edges, rows)


def list_assumptions(*, category: str | None = None, limit: int = 50) -> list[dict]:
    sql = "SELECT id, canonical_name, statement, category FROM assumptions"
    args: list = []
    if category:
        sql += " WHERE category = %s"; args.append(category)
    sql += " ORDER BY updated_at DESC LIMIT %s"
    args.append(limit)
    with connect() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, args)
            return list(cur.fetchall())
