# Research mining + open-problem DB (Design + Implementation Plan)

Part of Phase 12 (self-hosting) — the **priority first build** of that phase.

**Status (2026-05-30):**

| Slice | Commit | Status |
|---|---|---|
| 1 — Postgres+pgvector foundation, arXiv + IACR ePrint metadata ingest | `d2f7a9a` | ✓ |
| 2a — embeddings (bge-m3), LLM extraction (qwen2.5:14b, JSON-schema), 2-stage dedup, review queue | `e3304e6` | ✓ |
| 2b — Textual TUI for the review queue | `e6376d5` | ✓ |
| 2c — crypto-relevance gate, canonical assumption whitelist, discrete confidence buckets, `reset --all --purge` | `42d3f51` | ✓ |
| 2c.1 — assumption denylist + TUI rendering for `new_assumption` items + `clean-assumptions` retroactive cleanup | `e2604f4`, `7435cf2` | ✓ |
| 2d — full-text PDF ingestion | — | later |
| **3 — progress_events + assumption security-margin timelines** | — | **next** |
| 4 — FastAPI read API + web reader + cron + ntfy digest | — | after 3 |

**Run history:**
- 1st run (no gate, quant-ph included): 596 papers → 121 problems, 32 assumptions, 45 review items. Heavy noise from quant-ph + LLM-security.
- 2nd run (slice 2c, gate active, quant-ph dropped): 596 papers → **117 crypto / 479 filtered**, **74 problems**, **40 assumptions**, 14 review (3 novel-assumption). Substantial quality jump.

**Failure modes addressed by 2c / 2c.1:**
1. ✅ arXiv `quant-ph` leakage → dropped from sources.
2. ✅ cs.CR LLM-security creep → caught by the gate's negative-example list.
3. ✅ Junk assumption names ("Bell inequalities", "Grover's algorithm", "depolarizing noise") → denylist routes them to review queue rather than auto-merging; `clean-assumptions` sweeps existing rows.
4. Paper-specific noise (multi-variant problems from one paper's future-work bullets) — still present, partly fundamental to the data.
5. ✅ Confidence calibration → discrete 0.3/0.6/0.9 buckets enforced.

**Slice 3 sketch:**
- Re-LLM pass over already-`crypto_relevant=true` papers extracting `attacks` / `weakens` events as structured deltas (e.g. *"cost of MLWE-512 cryptanalysis dropped from 2^155 to 2^148"*).
- New table `progress_events (id, paper_id, assumption_id, event_date, delta_text, delta_kind, embedding)`.
- `nxc mine research timeline <assumption_id>` lists events ordered chronologically — the "is LWE still comfortable?" UI.
- Cost: ~20-30 min LLM time on the existing 117 crypto papers.

**Slice 4 sketch:**
- FastAPI read-API exposing the knowledge graph (papers, problems, assumptions, edges, timelines).
- Small HTMX/Jinja frontend at `nxcmine.gxdelerue.dedyn.io` (Caddy vhost, LE cert via deSEC).
- systemd timer for periodic `ingest && extract`.
- ntfy webhook for weekly digest of new problems + revisions + queue items.

## Overview

A research-intelligence pipeline for (primarily) cryptography/PQC: mine papers
from selected sources, extract what's *new* (contributions/progress) and what's
*unresolved* (open problems, assumptions), and maintain a deduplicated
**knowledge graph** queryable from terminal and web.

```
ingest (arXiv / IACR ePrint / DBLP venue lists)
  → resolve full text (free preprint; else metadata-only + backlog)
  → extract (heuristics locate regions → LLM structures): contributions, open problems, assumptions
  → normalize + dedup (embed → retrieve → LLM-confirm → review queue)
  → store (Postgres + pgvector knowledge graph)
  → surface (nxc mine CLI + read-only web reader; weekly ntfy digest)
```

Reuses existing/planned infra: **Postgres + pgvector** (Phase 10b RAG), **Ollama**
for extraction/embeddings, **Caddy + Tailscale** to serve, **ntfy** for digests,
optionally **Paperless** to hold PDFs and **SearXNG** as a search frontend.

## Locked decisions

- **Scope:** configurable, category-organized sources. Start categories:
  **Crypto/PQC, CS/Complexity, Math.** New category = config edit, no code change.
- **Tracks:** full knowledge graph — **problems + progress + assumptions**,
  including a cryptanalytic **security-margin timeline** per assumption/scheme.
- **Dedup:** two-stage — embed → retrieve nearest → **LLM "same problem?" confirm**
  → review queue for uncertain merges. Canonical statement + aliases per cluster;
  **hierarchical** parent/child (generalize/specialize) links, not equality-only.
- **Full-text:** resolve venue entries to a free preprint (arXiv/ePrint) for full
  extraction; when none exists, store **metadata-only** and add to a
  **want-fulltext backlog**. Fetcher is a **pluggable access layer** — future
  institutional access (credentials/proxy) re-runs the backlog and promotes those
  entries. Fully legal in the meantime.
- **Privacy:** papers are public → **no anonymizer gate**. `--smart` (Claude)
  escalation freely available for hard/low-confidence extractions; default local.
- **Interface:** terminal **and** web (`nxc mine` + small read-only web reader
  behind Caddy/Tailscale).
- **Build:** **standalone, clean modules.** Keep job-runner / store+dedup /
  read-API+web / extraction-harness as separated internal modules so the shared
  mining framework can be extracted when Phase 13 (`nxc mine` for language content)
  arrives. Do not build the abstraction upfront against a single consumer.

## Sources

Category-organized config (`~/.config/nxc/mine/sources.toml`, seeded by nix,
user-owned, `nxc mut`-tracked):

```toml
[categories.crypto]
arxiv  = { categories = ["cs.CR", "quant-ph"], keywords = [] }
eprint = { enabled = true, areas = ["lattices","isogenies","mpc","zk"] }
venues = ["CRYPTO","EUROCRYPT","ASIACRYPT","TCC","PKC","CHES","CCS","SP","USENIXSEC","PQCrypto"]

[categories.complexity]
arxiv  = { categories = ["cs.CC","cs.DS","cs.IT"] }
venues = ["STOC","FOCS","CCC","SODA","ITCS"]

[categories.math]
arxiv  = { categories = ["math.NT","math.AG","math.CO","math.GR"] }
venues = []   # journals — arXiv-only to start
```

Ingestion mechanics:
- **arXiv** — Atom API, filter by category + date + optional keyword query;
  OAI-PMH for backfill. PDF/source freely available.
- **IACR ePrint** — API + RSS + per-year listings; metadata + PDF freely available.
- **Venues** — **DBLP** for structured venue listings (authoritative metadata),
  then match each entry to its arXiv/ePrint preprint by DOI/title/author for full
  text. No preprint → metadata-only + backlog.

## Data model (Postgres + pgvector)

**Nodes**
- `papers` — id, source, ext ids (arXiv/ePrint/DOI), title, authors, date, venue,
  category, abstract, fulltext_ref (nullable), tags[], embedding, fulltext_status
  (`full` | `metadata_only`)
- `problems` — id, canonical_statement, aliases[], status (`open` | `partial` |
  `solved`), category, embedding, parent_id (nullable → hierarchy)
- `assumptions` — id, canonical_name, statement, category, embedding (e.g. LWE,
  MLWE, SVP-hardness, isogeny path-finding, …)
- `review_queue` — id, kind (`merge` | `link` | `status_change`), payload, created

**Edges**
- `paper_problem` — paper_id, problem_id, role (`states` | `addresses` | `solves`), confidence
- `paper_assumption` — paper_id, assumption_id, role (`introduces` | `relies_on` | `attacks` | `weakens`), confidence
- `problem_problem` — parent_id, child_id, kind (`specializes` | `related`)
- `progress_events` — assumption_id (or scheme), paper_id, date, delta (text/structured),
  embedding → yields the per-assumption **security-margin timeline**
- `fulltext_backlog` — paper_id, reason, requested_at (want-fulltext queue)

All free-text node fields embedded with `nomic-embed-text` for retrieval + dedup.

## Extraction

Hybrid, to keep local token budget down:
1. **Heuristics** locate candidate regions cheaply — section headers ("Open
   Problems", "Future Work", "Open Questions", "Our Contributions"), cue phrases
   ("it remains open whether", "we leave as future work", "an interesting open
   problem", "we assume", "under the … assumption").
2. **LLM** structures the candidates → JSON: `[{type, statement, context,
   confidence}]` for problems; assumptions list with role. Default local
   (qwen3.6:27b for structured, glm-4.7-flash for reasoning-heavy); escalate
   low-confidence to `--smart` (Claude) — allowed, papers are public.

## Deduplication (the headline)

Per extracted problem:
1. Embed → pgvector **retrieve** top-k nearest existing problems (same category bias).
2. **LLM judges** each candidate pair: same / specializes / related / distinct.
3. **Same** → merge (add as alias, keep canonical); **specializes/related** →
   hierarchical edge; **distinct** → new node. Confidence below threshold → **review
   queue** (surface + suggest, never auto-commit).
4. Maintain canonical statement + aliases[] per cluster.

Lifecycle: a later paper claiming resolution surfaces a candidate `solves` link +
`status_change` in the review queue for confirmation (not auto-applied).

## Interface — `nxc mine` + web

```
nxc mine ingest [--category crypto] [--since DATE]   # pull new papers
nxc mine run                                         # full pipeline (ingest→extract→dedup)
nxc mine problems [--category] [--status open] [--search "..."]
nxc mine problem <id>                                # detail: statement, papers, hierarchy, status
nxc mine assumption <id>                             # detail + security-margin timeline
nxc mine review                                      # work the review queue (merges/links/status)
nxc mine backlog                                     # want-fulltext list
nxc mine serve                                       # FastAPI read API + web reader
```

Web: small read-only reader behind Caddy/Tailscale — browse problems by category,
hierarchy tree, assumption timelines, "what's new this week", full-text search.
(Mutations — merges, status changes — go through the CLI `review` queue.)

Update cadence: cron (weekly default, configurable) → `nxc mine run` → ntfy digest
of new problems + pending review items.

## Module boundaries (for later shared-framework extraction)

Keep these as separate internal modules from day one:
- `jobrunner` — scheduled ingest→extract→store with resume/retry (domain-agnostic)
- `store` — Postgres+pgvector schema + embed/retrieve/LLM-confirm/review-queue dedup (domain-agnostic core, domain node types injected)
- `api` — FastAPI read API + web reader shell (domain-agnostic)
- `extract` — LLM-extraction harness, local-default + `--smart` escalation (domain-agnostic)
- `research/` — the only domain-specific module: sources, paper parsing, crypto taxonomy, problem/assumption/progress logic

Phase 13's content-mining becomes a sibling `language/` domain module over the same
first four. **Do not** pre-build the framework — let these boundaries make the
extraction cheap when the second consumer exists.

## Nix packaging

```
pkgs/nxc-mine/
  default.nix          — buildPythonApplication (httpx, FastAPI/uvicorn, psycopg, tomli)
  nxc_mine.py          — entry: argparse → ingest | run | problems | review | serve | ...
  jobrunner.py  store.py  api.py  extract.py
  research/            — domain module (sources, parsing, taxonomy)
  sources.toml         — default config, seeded by activation
```

- `pkgs/nxc/default.nix`: add `nxc-mine` to runtimeInputs.
- `nxc-main.sh`: `mine) shift; exec nxc-mine "$@" ;;` + usage line.
- Postgres: add a `nxcmine` database + pgvector extension (shared PG instance with
  atuin / Phase-10b RAG).
- `sources.toml` seeded by activation + registered in `nxc mut` (alongside the
  `ai.toml` / `claude.toml` TODO).
- `services.caddy` route for the web reader; Tailscale-only exposure.

## Implementation order

1. **Schema + ingest** ✓ (`d2f7a9a`) — Postgres+pgvector via `services.postgresql` add-on; `postgresql-nxcmine-ext` oneshot creates the vector extension as superuser (it isn't trusted in this build). `nxc mine research init/ingest/papers` with arXiv (Atom API) and IACR ePrint (OAI-PMH) sources. Schema tracks `first_published` / `last_revised` / `latest_version` so new-vs-revised is a column query, not a flag.
2. **Embeddings + extraction harness + dedup + review queue** ✓ (`e3304e6`) —
   - Embeddings via `bge-m3` (1024d, 8192-token ctx) using Ollama's legacy `/api/embeddings` (the newer `/api/embed` is flaky across versions; legacy is ubiquitous and bge-m3 is small enough that per-request HTTP overhead is negligible).
   - Extraction via `qwen2.5:14b` in JSON-schema format mode. Note: `qwen3.6:27b` and `glm-4.7-flash` both fail to load on this ROCm/Ollama build (`rocBLAS: Could not initialize Tensile host`); investigate after a ROCm bump.
   - Two-stage dedup: embed claim → pgvector cosine retrieve top-K → LLM `judge_pair` only when `cosine ≥ similarity_high`. Thresholds in `~/.config/nxc/mine/mine.toml` `[dedup]`.
   - ThreadPoolExecutor parallelises the slow extract call (`extract.concurrency`, default 2); dedup decisions stay serial to avoid merge races.
   - Defensive: `_vec_literal()` returns None for empty/null vectors → SQL NULL; confidences clamped to [0,1]; empty `canonical_*` skipped.
3. **TUI review** ✓ (`e6376d5`) — Textual app at `nxc mine research review` with a/m/s/R/e/x/n/p/q bindings; `apply_review_decision` is the single DB-write path, resolving the queue row LAST so crashes leave items pending. `--json` keeps the non-interactive dump.
4. **Prompt refinement + source narrowing** (next) — extract-prompt negative examples, canonical assumption whitelist, confidence calibration (0.3/0.6/0.9 by cue strength), drop arXiv `quant-ph` or replace with PQC keyword filter, add an optional cheap "is this paper about cryptography?" gate before extraction.
5. **Full-text PDF ingestion** — `pdftotext`/`marker`, section-aware extraction (`Open Problems` / `Future Work` / `Conclusion`), embedding chunking with overlap.
6. **Venue ingest** — DBLP listings → preprint matching → metadata-only + backlog fallback; pluggable access layer interface (institutional access = later impl).
7. **Progress/assumption timelines** — `progress_events`, security-margin view.
8. **Web reader + read API** — FastAPI + small frontend behind Caddy/Tailscale.
9. **Cadence + digest** — cron `nxc mine research ingest && extract` + ntfy weekly digest; config seeding + `nxc mut` wiring.

## Open items (decide later)

- Exact venue list per category + math subfields (starter set in `sources.toml`).
- Institutional access layer implementation (credentials/proxy) — interface now,
  impl when needed.
- Whether PDFs live in Paperless vs a dedicated store.
- SearXNG engine for the problem/paper DB.
- Shared mining-framework extraction — triggered at Phase 13.
