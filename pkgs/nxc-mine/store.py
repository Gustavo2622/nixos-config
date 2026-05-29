"""Postgres helpers: connection, schema init, paper upserts, ingest-run tracking."""

from __future__ import annotations

import datetime as dt
import pathlib
from contextlib import contextmanager
from dataclasses import dataclass, field
from typing import Iterable, Iterator

import psycopg
from psycopg.rows import dict_row

from config import DB_DSN

_SCHEMA_PATH = pathlib.Path(__file__).parent / "schema.sql"


@dataclass
class Paper:
    """Normalized paper record produced by source clients."""

    source: str            # 'arxiv' | 'eprint' | 'venue:...'
    ext_id: str            # source-native ID
    title: str
    authors: list[str]
    first_published: dt.date | None
    last_revised: dt.date | None
    latest_version: str | None     # 'v1'/'v3' for arXiv, revision count or datestamp for ePrint
    category: str          # our taxonomy bucket
    source_categories: list[str]
    abstract: str | None
    pdf_url: str | None


@contextmanager
def connect() -> Iterator[psycopg.Connection]:
    """Open a connection; caller owns the transaction (autocommit off by default)."""
    with psycopg.connect(DB_DSN, row_factory=dict_row) as conn:
        yield conn


def init_schema() -> None:
    """Apply schema.sql idempotently. CREATE IF NOT EXISTS throughout."""
    sql = _SCHEMA_PATH.read_text()
    with connect() as conn:
        with conn.cursor() as cur:
            cur.execute(sql)
        conn.commit()


def upsert_papers(papers: Iterable[Paper]) -> tuple[int, int]:
    """Insert new papers; update existing rows when revision info has changed.

    Returns (new_count, updated_count). An "update" only counts when the
    incoming `last_revised` is newer than what's stored OR `latest_version`
    has changed — re-ingesting the same row produces no count. This is what
    lets us distinguish genuine revisions from noisy re-runs.
    """
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
                        p.source,
                        p.ext_id,
                        p.title,
                        p.authors,
                        p.first_published,
                        p.last_revised,
                        p.latest_version,
                        p.category,
                        p.source_categories,
                        p.abstract,
                        p.pdf_url,
                    ),
                )
                row = cur.fetchone()
                if row is None:
                    # Existing row, nothing changed → no-op.
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
                """
                INSERT INTO ingest_runs (source, category, started_at)
                VALUES (%s, %s, NOW())
                RETURNING id, source, category, started_at
                """,
                (source, category),
            )
            row = cur.fetchone()
        conn.commit()
    return IngestRun(**row)


def finish_ingest_run(
    run_id: int,
    *,
    found: int,
    new: int,
    updated: int,
    errors: int = 0,
    notes: str | None = None,
) -> None:
    with connect() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                UPDATE ingest_runs
                   SET finished_at = NOW(),
                       papers_found = %s,
                       papers_new = %s,
                       papers_updated = %s,
                       errors = %s,
                       notes = %s
                 WHERE id = %s
                """,
                (found, new, updated, errors, notes, run_id),
            )
        conn.commit()


def list_papers(
    *,
    category: str | None = None,
    source: str | None = None,
    search: str | None = None,
    only_new: bool = False,
    only_revised: bool = False,
    limit: int = 50,
) -> list[dict]:
    """Listing for `nxc mine research papers`.

    `only_new`: papers where first_published == last_revised (no revision yet).
    `only_revised`: papers where last_revised > first_published.
    """
    sql = (
        "SELECT id, source, ext_id, title, authors, first_published, last_revised, "
        "latest_version, category, source_categories, pdf_url FROM papers"
    )
    where = []
    args: list = []
    if category:
        where.append("category = %s")
        args.append(category)
    if source:
        where.append("source = %s")
        args.append(source)
    if search:
        where.append("(title ILIKE %s OR abstract ILIKE %s)")
        args.append(f"%{search}%")
        args.append(f"%{search}%")
    if only_new:
        where.append("last_revised IS NOT DISTINCT FROM first_published")
    if only_revised:
        where.append("last_revised > first_published")
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
            row = cur.fetchone()
            return int(row["n"]) if row else 0
