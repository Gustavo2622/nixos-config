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
  embedding         vector(1024),                         -- mxbai-embed-large dim; filled later
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

-- Derived preprint flag (preprint sources lack peer review → lower source authority).
-- Computed; folds into displayed confidence rather than being baked into stored values.
ALTER TABLE papers ADD COLUMN IF NOT EXISTS
  is_preprint BOOLEAN GENERATED ALWAYS AS (source IN ('arxiv', 'eprint')) STORED;

-- Tracking which papers have been embedded + extracted, so we can resume / re-run.
ALTER TABLE papers ADD COLUMN IF NOT EXISTS embedded_at  TIMESTAMPTZ;
ALTER TABLE papers ADD COLUMN IF NOT EXISTS extracted_at TIMESTAMPTZ;

-- Migrate papers.embedding from vector(768) (initial nomic-embed-text) to
-- vector(1024) (current mxbai-embed-large). Safe while the column is unfilled;
-- if already 1024 (or filled at 1024), the EXCEPTION block swallows it.
DO $$
BEGIN
  ALTER TABLE papers ALTER COLUMN embedding TYPE vector(1024);
EXCEPTION WHEN OTHERS THEN NULL;
END$$;

-- ───────────────────── problems / assumptions / edges ─────────────────────

-- Open problems, conjectures, future-work items the canonical statement bucket.
CREATE TABLE IF NOT EXISTS problems (
  id                   BIGSERIAL PRIMARY KEY,
  canonical_statement  TEXT        NOT NULL,
  aliases              TEXT[]      NOT NULL DEFAULT '{}',  -- alternate phrasings from merges
  problem_type         TEXT        NOT NULL,               -- 'open_problem' | 'future_work' | 'conjecture'
  status               TEXT        NOT NULL DEFAULT 'open',-- 'open' | 'partial' | 'solved'
  category             TEXT        NOT NULL,
  embedding            vector(1024),
  parent_id            BIGINT      REFERENCES problems(id) ON DELETE SET NULL,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS problems_status_idx   ON problems (status);
CREATE INDEX IF NOT EXISTS problems_category_idx ON problems (category);
CREATE INDEX IF NOT EXISTS problems_embedding_idx ON problems USING hnsw (embedding vector_cosine_ops);

-- Hardness assumptions schemes rely on (LWE, MLWE, isogeny path, …).
CREATE TABLE IF NOT EXISTS assumptions (
  id              BIGSERIAL PRIMARY KEY,
  canonical_name  TEXT        NOT NULL UNIQUE,             -- 'LWE' | 'MLWE-512' | 'SIDH'
  statement       TEXT        NOT NULL,
  aliases         TEXT[]      NOT NULL DEFAULT '{}',
  category        TEXT        NOT NULL,
  embedding       vector(1024),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS assumptions_embedding_idx ON assumptions USING hnsw (embedding vector_cosine_ops);

-- Paper → problem (with role).
CREATE TABLE IF NOT EXISTS paper_problem (
  paper_id    BIGINT NOT NULL REFERENCES papers(id)   ON DELETE CASCADE,
  problem_id  BIGINT NOT NULL REFERENCES problems(id) ON DELETE CASCADE,
  role        TEXT   NOT NULL,                            -- 'states' | 'addresses' | 'solves'
  confidence  REAL   NOT NULL CHECK (confidence >= 0 AND confidence <= 1),
  evidence    TEXT,                                       -- exact substring from paper for audit
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (paper_id, problem_id, role)
);
CREATE INDEX IF NOT EXISTS paper_problem_problem_idx ON paper_problem (problem_id);

-- Paper → assumption (with role).
CREATE TABLE IF NOT EXISTS paper_assumption (
  paper_id       BIGINT NOT NULL REFERENCES papers(id)      ON DELETE CASCADE,
  assumption_id  BIGINT NOT NULL REFERENCES assumptions(id) ON DELETE CASCADE,
  role           TEXT   NOT NULL,                          -- 'introduces' | 'relies_on' | 'attacks' | 'weakens'
  parameters     TEXT,                                     -- 'n=512, q=2^14' or null
  confidence     REAL   NOT NULL CHECK (confidence >= 0 AND confidence <= 1),
  evidence       TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (paper_id, assumption_id, role)
);
CREATE INDEX IF NOT EXISTS paper_assumption_assumption_idx ON paper_assumption (assumption_id);

-- Hierarchical edges between problems (parent specializes/related to child).
CREATE TABLE IF NOT EXISTS problem_problem (
  parent_id  BIGINT NOT NULL REFERENCES problems(id) ON DELETE CASCADE,
  child_id   BIGINT NOT NULL REFERENCES problems(id) ON DELETE CASCADE,
  kind       TEXT   NOT NULL,                             -- 'specializes' | 'related'
  PRIMARY KEY (parent_id, child_id, kind),
  CHECK (parent_id <> child_id)
);

-- Review queue for uncertain dedup / extraction decisions.
-- payload jsonb holds full proposal + candidate matches + similarity scores.
CREATE TABLE IF NOT EXISTS review_queue (
  id               BIGSERIAL PRIMARY KEY,
  kind             TEXT        NOT NULL,                   -- 'new_problem' | 'new_assumption' | 'merge_candidate' | 'status_change'
  payload          JSONB       NOT NULL,
  source_paper_id  BIGINT      REFERENCES papers(id) ON DELETE CASCADE,
  status           TEXT        NOT NULL DEFAULT 'pending', -- 'pending' | 'accepted' | 'rejected' | 'deferred'
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  resolved_at      TIMESTAMPTZ,
  resolution       TEXT                                    -- free-form note from review action
);
CREATE INDEX IF NOT EXISTS review_queue_status_idx ON review_queue (status, created_at);
