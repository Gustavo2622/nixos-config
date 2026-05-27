# nxc ai — Multi-provider AI CLI (Design + Implementation Plan)

Companion to [`nxc-design.md`](./nxc-design.md). Covers the `nxc ai` subcommand
only. **Status: designed, not yet implemented** (Phase 10 of the unified-flake
plan). This doc is the spec to build from later.

## Overview

`nxc ai` is a privacy-first, multi-provider AI CLI. Local Ollama is the default
for everything (private, no limits); remote providers are opt-in escalations.

| Provider | Role | Trigger |
|----------|------|---------|
| Ollama (local) | Default. Private, unlimited. | (default) |
| Claude CLI (Max sub) | Escalation for hard problems. | `--smart` |
| Groq (free tier) | Fast open-model inference, second opinion. | `--fast` |

Goals:
- One `stream(messages, model, params) -> iterator[str]` interface across all three.
- A **mode** system (concise/teaching/discussion/review/code + user-defined) that
  composes with providers.
- Stateless one-shot `ask` and persistent `chat`, both able to use named sessions.
- Plain streaming output by default; `--json` / `--raw` for scripting/pipes.

## Architecture

Standalone Python app, **same pattern as `pkgs/nxc-sandbox/`**: pure-stdlib +
a couple of pinned deps, `buildPythonApplication`, delegated from the shell `nxc`
dispatcher via `exec`.

```
nxc-main.sh:  ai) shift; exec nxc-ai "$@" ;;
```

### Decisions (locked)

- **HTTP:** `httpx` for all three providers. **No `ollama` SDK** — it is a thin
  httpx+pydantic wrapper over the same `/api/chat` endpoint, would make Ollama
  asymmetric with the raw-httpx Groq/Claude paths, and adds pydantic + a pinned
  httpx range to the closure for no real gain. One shared SSE/ndjson stream
  helper, three small parallel provider modules.
- **Modes are full profiles:** prelude (system prompt) + optional `provider`,
  `model`, `temperature`. Precedence: **explicit flag > mode > config default**
  (applies independently to provider, model, params).
- **Claude runs raw (no sandbox), locked to pure text completion** — see below.
  Sandbox-free is correct because with tools disabled it cannot touch the
  filesystem; agentic Claude with file access stays behind `nxc claude` (which
  *is* sandboxed). The isolation boundary lands exactly where the capability is.
- **Sessions:** `ai ask` is stateless by default; both `ask` and `chat` can
  persist via `--session`. Unnamed `chat` resumes/creates a `default` session;
  `--session NAME` for others.
- **Remote warn-once:** first use of any remote provider (claude/groq) prints a
  one-time confirmation ("text leaves the machine; no anonymizer yet"), remembered
  thereafter. (The Phase-10 anonymizer pipeline will later sit in front of remote
  providers; until then raw text is sent.)

## Providers

A provider module exposes:

```python
def stream(messages: list[dict], model: str, params: dict) -> Iterator[str]: ...
```

`messages` is the OpenAI-style `[{"role": ..., "content": ...}]` list. The caller
builds it (mode prelude as leading `system` message + session history + new input)
and renders the streamed token chunks.

### Ollama (default)

- POST `{host}/api/chat`, body `{"model", "messages", "stream": true, "options": {...}}`.
- Response is **ndjson**: one JSON object per line, token in
  `obj["message"]["content"]`, final line has `"done": true`.
- Host from `providers.ollama.host` (default `http://localhost:11434`; also
  reachable over Tailscale on `:11434`).

### Groq (`--fast`)

- POST `{endpoint}/chat/completions` (OpenAI-compatible),
  `{"model", "messages", "stream": true, "temperature": ...}`.
- Response is **SSE**: `data: {json}\n\n` lines, token in
  `choices[0].delta.content`, terminated by `data: [DONE]`.
- Auth: `Authorization: Bearer <key>`. **Key resolution order:**
  `--api-key-file` flag → `$GROQ_API_KEY` env → `providers.groq.api_key_file`.
- Default model: **decide later** — `llama-3.3-70b-versatile` is the placeholder
  in the seeded config; swap in the toml anytime. (Open item, see below.)

### Claude (`--smart`)

Shell out to the `claude` CLI (rides the Max subscription via `claude-code`; no API
token). **Locked to a pure text completion** so it behaves exactly like the HTTP
providers:

```
claude -p \
  --tools "" \                       # disable ALL tools → no file/bash access
  --bare \                           # skip hooks, CLAUDE.md auto-discovery, auto-memory, keychain
  --append-system-prompt "<mode prelude>" \
  --model <model> \                  # alias (e.g. "sonnet") or full id
  --no-session-persistence \         # nxc owns sessions, not claude
  --output-format stream-json --include-partial-messages
```

- `--tools ""` is the security-critical flag: without it, `claude -p` is the full
  agentic CLI and **can read/edit files and run bash in the CWD** even in print mode.
- Stream by parsing the `stream-json` events; extract assistant text deltas.
  (Multi-turn session history is replayed by prepending prior messages — claude
  print mode is one-shot, so we pass the accumulated context each call. Revisit:
  `--input-format stream-json` if richer multi-turn is needed.)
- Optional `--max-budget-usd` cap is available if we ever want a spend ceiling.

## CLI surface

```
nxc ai ask "question"                       # default provider (Ollama), stateless
nxc ai ask --smart "hard question"          # → Claude
nxc ai ask --fast "quick question"          # → Groq
nxc ai ask --mode review < file.nix         # mode + piped stdin
nxc ai ask --session refactor "..."         # append a one-shot to a named session
nxc ai chat                                 # persistent session, resumes "default"
nxc ai chat --session refactor              # named session
nxc ai chat --provider claude               # pick provider explicitly

Global flags:
  --provider {ollama|claude|groq}   explicit provider (overrides --smart/--fast/mode/default)
  --smart                           shorthand for --provider claude
  --fast                            shorthand for --provider groq
  --mode <name>                     mode profile (default from config)
  --model <model>                   override model
  --session [NAME]                  persist to session (NAME optional → "default")
  --json                            structured output (full response object)
  --raw                             text only, no formatting (for pipes)
  --api-key-file <path>             Groq key file override
```

Resolution per request: load `ai.toml` → resolve provider (flag > mode.provider >
default_provider) → resolve model (`--model` > mode.model > provider.model) →
resolve params (mode.temperature etc.) → assemble messages → stream → persist if
`--session`.

## Config: `~/.config/nxc/ai.toml`

Seeded by nix activation exactly like `sandbox/claude.toml` (user-owned after,
never clobbered by rebuild). To be wired into `nxc mut` alongside the existing
`claude.toml` TODO.

```toml
default_provider = "ollama"
default_mode     = "concise"

[providers.ollama]
host  = "http://localhost:11434"
model = "qwen3.6:27b"

[providers.groq]
endpoint     = "https://api.groq.com/openai/v1"
model        = "llama-3.3-70b-versatile"   # TODO: finalize model choice
api_key_file = "/run/secrets/groq_api_key" # sops-rendered, user-readable

[providers.claude]
model = "sonnet"                            # alias passed to `claude --model`

[modes.concise]
prelude = "Answer concisely. No preamble or filler."

[modes.teaching]
prelude = "Explain step by step for a capable learner; show reasoning."

[modes.discussion]
prelude = "Be a thoughtful interlocutor; surface trade-offs, push back."

[modes.review]
prelude     = "You are a code reviewer. Prioritize correctness bugs, then clarity."
provider    = "claude"
temperature = 0.0

[modes.code]
prelude = "Output code only, minimal prose. Match surrounding style."
```

## Sessions

`~/.local/state/nxc/ai/sessions/<name>.json`:

```json
{
  "name": "default",
  "created": "2026-05-27T12:00:00Z",
  "updated": "2026-05-27T12:05:00Z",
  "provider": "ollama",
  "mode": "concise",
  "messages": [
    {"role": "user", "content": "..."},
    {"role": "assistant", "content": "..."}
  ]
}
```

- Unnamed `chat` → `default.json`. `--session NAME` → `NAME.json`.
- `ask --session NAME` appends one exchange to that session.
- (Future helpers: `nxc ai session list|show|rm` — deferred, not v1.)

## Output modes

- **Default:** plain streaming text to the terminal (no markdown-renderer dep).
- `--json`: full structured response object (for scripting).
- `--raw`: text only, no decoration (for pipes).
- **Later polish (not v1):** pretty markdown via `glow` when stdout is a TTY;
  **HTML output** mode. Both deferred.

## Secrets (Groq key)

The CLI reads the key from a file/env (see resolution order above). The nix side
must render the Groq API key as a sops-nix secret readable by the user, e.g.
`sops.secrets.groq_api_key = { owner = vars.username; };` → `/run/secrets/groq_api_key`.
**Small separate nix step; does not block the CLI build** (CLI degrades gracefully:
`--fast` errors with a clear "no Groq key configured" message if absent).

## Nix packaging

```
pkgs/nxc-ai/
  default.nix          — buildPythonApplication (httpx dep), like nxc-sandbox
  nxc_ai.py            — entry: argparse → ask | chat; resolution; output
  providers/
    ollama.py          — ndjson stream
    groq.py            — SSE stream
    claude.py          — subprocess claude -p stream-json
  ai.toml              — default config, seeded by activation
```

- `default.nix`: `propagatedBuildInputs = [ python3Packages.httpx ]` (+ `tomli`
  fallback if `tomllib` unavailable, mirroring nxc-sandbox). `makeWrapperArgs`
  prefixing PATH with `claude` (claude-code) for the `--smart` path.
- `pkgs/nxc/default.nix`: add `nxc-ai = callPackage ../nxc-ai {};` to runtimeInputs.
- `nxc-main.sh`: `ai) shift; exec nxc-ai "$@" ;;` + usage line.
- Activation seeding of `ai.toml`: extend the existing `sandbox/claude.toml`
  activation logic in `modules/mutable/` (or wherever claude.toml is seeded);
  register `ai.toml` in the `nxc mut` registry.

## Implementation order

1. **Skeleton + packaging** — `pkgs/nxc-ai/` with argparse, `ask`/`chat`
   subcommands, config loader, resolution logic (provider/model/mode precedence).
   Wire `nxc-ai` into `pkgs/nxc` runtimeInputs + dispatcher. `nh os build` green.
2. **Ollama provider** — ndjson streaming `ask`. The default path end-to-end.
3. **Mode system** — load modes from toml, inject prelude, apply provider/model/
   temperature pins with correct precedence.
4. **Output modes** — `--json` / `--raw` alongside default streaming.
5. **Sessions** — persistence read/write; `chat` loop resuming `default`;
   `--session NAME`; `ask --session`.
6. **Groq provider** (`--fast`) — SSE streaming, key resolution, graceful error
   when key absent. **+ sops-nix `groq_api_key` secret** on the nix side.
7. **Claude provider** (`--smart`) — `claude -p` subprocess with the locked flag
   set, stream-json parsing.
8. **Remote warn-once** — confirmation gate + remembered flag
   (`~/.local/state/nxc/ai/.remote-acknowledged`).
9. **Config seeding + `nxc mut`** — activation seeds `ai.toml`, register in mut.

## Open items (decide later)

- **Groq default model** — finalize (`llama-3.3-70b-versatile` placeholder vs a
  Qwen/other on Groq).
- **`glow` markdown + HTML output** — deferred polish.
- **`nxc ai session` management subcommands** (list/show/rm) — deferred.
- **Anonymizer pipeline** in front of remote providers — separate Phase-10
  workstream (pgvector RAG + spaCy/qwen anonymize), tracked in the main plan.
