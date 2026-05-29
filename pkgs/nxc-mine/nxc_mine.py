#!/usr/bin/env python3
"""nxc-mine — research/content mining framework for nxc.

First slice: `nxc mine research <init|ingest|papers>`.
`nxc mine language ...` (Phase 13) becomes a sibling subcommand later; the
namespace was carved out so we don't have to rename when that lands.
"""

from __future__ import annotations

import argparse
import datetime as dt
import sys
from typing import Iterable

import config
import store


# ─── research subcommand ────────────────────────────────────────────────────


def _cmd_research_init(_: argparse.Namespace) -> int:
    store.init_schema()
    print("Schema applied (papers, ingest_runs, pgvector extension).")
    return 0


def _cmd_research_ingest(args: argparse.Namespace) -> int:
    """Pull recent papers from the chosen sources into the DB."""
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
                        store.finish_ingest_run(run.id, found=0, new=0, updated=0, errors=0,
                                                notes="eprint disabled for this category")
                        continue
                    from sources import eprint

                    papers, errs = eprint.fetch(
                        since=since,
                        areas=ep.get("areas") or None,
                        our_category=category,
                    )
                else:
                    print(f"  unknown source: {source}", file=sys.stderr)
                    store.finish_ingest_run(run.id, found=0, new=0, updated=0, errors=1,
                                            notes="unknown source")
                    total_err += 1
                    continue

                new, upd = store.upsert_papers(papers)
                store.finish_ingest_run(
                    run.id, found=len(papers), new=new, updated=upd, errors=errs
                )
                total_found += len(papers)
                total_new += new
                total_upd += upd
                total_err += errs
                print(f"  found={len(papers)} new={new} revised={upd} errors={errs}")
            except Exception as e:  # noqa: BLE001 — surface for the run
                store.finish_ingest_run(run.id, found=0, new=0, updated=0, errors=1,
                                        notes=f"{type(e).__name__}: {e}")
                total_err += 1
                print(f"  FAILED: {type(e).__name__}: {e}", file=sys.stderr)

    print()
    print(f"Total: found={total_found} new={total_new} revised={total_upd} errors={total_err}")
    print(f"Papers in DB: {store.count_papers()}")
    return 1 if total_err and total_found == 0 else 0


def _cmd_research_papers(args: argparse.Namespace) -> int:
    rows = store.list_papers(
        category=args.category,
        source=args.source,
        search=args.search,
        only_new=args.only_new,
        only_revised=args.only_revised,
        limit=args.limit,
    )
    if not rows:
        print("(no papers match)")
        return 0
    for r in rows:
        fp = r["first_published"]
        lr = r["last_revised"]
        marker = "" if fp == lr else " ↺"  # revision indicator
        authors = ", ".join(r["authors"][:3])
        if len(r["authors"]) > 3:
            authors += f" + {len(r['authors']) - 3} more"
        print(f"[{r['source']}:{r['ext_id']}] {lr}{marker}  {r['title']}")
        print(f"    {authors}")
        if r["source_categories"]:
            print(f"    tags: {', '.join(r['source_categories'])}")
    print()
    print(f"({len(rows)} shown)")
    return 0


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
                     choices=["arxiv", "eprint"],
                     help="Restrict to a specific source (repeatable; default: all enabled)")
    ing.add_argument("--category", choices=list(config.CATEGORIES.keys()),
                     help="Restrict to one of our taxonomy buckets (default: all)")
    ing.add_argument("--window", type=int, default=config.DEFAULT_WINDOW_DAYS,
                     help=f"Days of history to ingest (default: {config.DEFAULT_WINDOW_DAYS})")
    ing.set_defaults(func=_cmd_research_ingest)

    pap = rsub.add_parser("papers", help="List papers in the DB")
    pap.add_argument("--category")
    pap.add_argument("--source")
    pap.add_argument("--search", help="ILIKE filter on title/abstract")
    pap.add_argument("--only-new", action="store_true",
                     help="Only papers with no revisions yet (first_published == last_revised)")
    pap.add_argument("--only-revised", action="store_true",
                     help="Only papers that have been revised since first publication")
    pap.add_argument("--limit", type=int, default=50)
    pap.set_defaults(func=_cmd_research_papers)

    return p


def main(argv: Iterable[str] | None = None) -> int:
    args = build_parser().parse_args(list(argv) if argv is not None else None)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
