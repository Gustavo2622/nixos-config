-- nxc-mine schema (first slice: papers + ingest log only).
-- Problem/assumption/dedup tables come in the next slice; embedding column
-- is already present so backfill is a column update rather than a migration.

CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE IF NOT EXISTS papers (
  id                BIGSERIAL PRIMARY KEY,
  source            TEXT        NOT NULL,                 -- 'arxiv' | 'eprint' | 'venue:STOC' | ...
  ext_id            TEXT        NOT NULL,                 -- '2509.12345' (arXiv) | '2026/123' (ePrint)
  title             TEXT        NOT NULL,
  authors           TEXT[]      NOT NULL DEFAULT '{}',
  first_published  DATE,                                  -- date of v1 / initial submission
  last_revised     DATE,                                  -- date of most recent revision (= first_published when never revised)
  latest_version    TEXT,                                  -- 'v1' (arXiv), revision count or datestamp (ePrint)
  category          TEXT        NOT NULL,                 -- our taxonomy: 'crypto' | 'complexity' | 'math'
  source_categories TEXT[]      NOT NULL DEFAULT '{}',    -- arXiv cats / ePrint area tags
  abstract          TEXT,
  pdf_url           TEXT,
  fulltext_status   TEXT        NOT NULL DEFAULT 'metadata_only',  -- 'metadata_only' | 'full'
  embedding         vector(768),                          -- nomic-embed-text dim; filled later
  ingested_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (source, ext_id)
);

CREATE INDEX IF NOT EXISTS papers_first_published_idx ON papers (first_published DESC);
CREATE INDEX IF NOT EXISTS papers_last_revised_idx    ON papers (last_revised DESC);
CREATE INDEX IF NOT EXISTS papers_category_idx        ON papers (category);
CREATE INDEX IF NOT EXISTS papers_source_idx          ON papers (source);

-- A paper is a "new publication" when first_published = last_revised, and a
-- revision when first_published < last_revised. Queries can filter on either.

CREATE TABLE IF NOT EXISTS ingest_runs (
  id              BIGSERIAL PRIMARY KEY,
  source          TEXT        NOT NULL,
  category        TEXT        NOT NULL,
  started_at      TIMESTAMPTZ NOT NULL,
  finished_at     TIMESTAMPTZ,
  papers_found    INT         NOT NULL DEFAULT 0,
  papers_new      INT         NOT NULL DEFAULT 0,        -- first time we see this paper
  papers_updated  INT         NOT NULL DEFAULT 0,        -- already in DB; revision/edit picked up
  errors          INT         NOT NULL DEFAULT 0,
  notes           TEXT
);
