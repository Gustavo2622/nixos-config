# nxc — NixOS Config Utility (v1 Design)

## Overview

Unified CLI tool for NixOS config introspection and mutable state management. Shell script (bash) that glues together `nix eval`, `jq`, `git merge-file`, and standard tools. Packaged in `pkgs/nxc/`, added to devShell and home-manager PATH.

Script is split into sourced subscripts for maintainability:
- `nxc.sh` — entry point, arg parsing, dispatch
- `lib/info.sh` — `nxc info` implementation
- `lib/mut.sh` — `nxc mut` implementation
- `lib/theme.sh` — `nxc theme` implementation
- `lib/health.sh` — `nxc health` implementation

## Architecture

### Config data extraction (Nix side)

Composable query modules in `pkgs/nxc/queries/`:

```
pkgs/nxc/queries/
  default.nix      — composes all query modules
  networking.nix    — hostname, ports
  packages.nix      — system/home package lists + counts
  services.nix      — enabled services
  theme.nix         — active theme, colors
  system.nix        — hostname, architecture, WM, DM
```

Each query file is a function `config: { ... }` that extracts serializable values from the NixOS config. Attributes that may not exist on all platforms use `or null` fallbacks:

```nix
# Example: queries/networking.nix
config: {
  hostname = config.networking.hostName or null;
  tcpPorts = config.networking.firewall.allowedTCPPorts or null;
  udpPorts = config.networking.firewall.allowedUDPPorts or null;
}
```

Fields that return `null` are omitted from the output (not shown, not "N/A"). On darwin, NixOS-specific fields are `null` and the output only shows darwin-relevant info. On NixOS, darwin-specific fields are `null` and the output only shows NixOS-relevant info.

Exposed as a flake output:

```nix
# flake.nix
configData = {
  "gustavo-Desktop" = import ./pkgs/nxc/queries self.nixosConfigurations.gustavo-Desktop.config;
  # Later: "gdel-MacBook" = import ./pkgs/nxc/queries self.darwinConfigurations.gdel-MacBook.config;
};
```

Benefits: pure eval, modular, adding a query = one file.

**Caching behavior**: Nix eval cache is invalidated when any tracked file in the repo changes. This means `nxc info` takes ~5-15s after any edit. To mitigate, the script caches the last eval result to `~/.local/state/nxc/last-info.json`. Use `nxc info --cached` to read the cache instantly. The cache is updated on every fresh eval.

**TODO (architecture revision)**: Consider generating the JSON at activation time (via `home.activation` or `system.activationScripts`) so `nxc info` reads a static file with zero eval overhead. Deferred to post-v1.

### Mutable state registry (Nix side)

`modules/mutable/default.nix` declares the program registry as a Nix attrset. At build time, generates a JSON manifest via home-manager activation at `~/.local/state/nxc/registry.json` containing:

- Program names
- Mutable file paths (absolute, expanded at build time via `config.home.homeDirectory`)
- Inclusion method + position
- Reload commands
- Declared config paths (for future `mut diff`)

**Note**: The registry location (`~/.local/state/nxc/`) is chosen for cross-platform compatibility (no `/run/current-system` on darwin). This may change if we find a better location — document any assumptions about this path.

The `nxc` script reads this manifest at runtime.

### Theme manifest (Nix side)

At build time, generates `~/.local/state/nxc/themes.json` (alongside the registry) containing pre-rendered color configs for each theme × each registered program with a `themeTemplate`:

```json
{
  "tokyonight-moon": {
    "hyprland": "$base00 = rgb(222436)\n...",
    "waybar": ":root { --base00: #222436; ... }",
    "ghostty": "background = 222436\n..."
  }
}
```

Pre-rendering all theme × program combinations is acceptable for v1 (1 theme, ~4 programs). This scales linearly and each entry is small (16 colors × a few lines). Known limitation: adding a theme or program requires a rebuild to update the manifest.

### Mutable file conventions

Each mutable file supports two zones:

1. **User-managed**: free-form content, no markers. Owned by the user.
2. **Tool-managed sections**: delimited by markers, each with a declared owner.

```
# User edits here (free-form, no markers)
bind = SUPER, T, exec, ghostty

# --- nxc:theme start ---
$base00 = rgb(222436)
$base01 = rgb(1e2030)
# --- nxc:theme end ---
```

Convention: tools only touch their own marked sections. User content outside markers is never modified by any tool. Future tools (beyond `nxc theme`) follow the same `# --- nxc:<owner> start/end ---` pattern.

### Inclusion hooks

For each registered program, Nix inserts an inclusion hook in the declarative config at the configured position (per-program, not universal). The hook sources/includes/dofiles the mutable path. Nix never writes to the mutable path itself.

**Seeding**: Implemented as a `home.activation` script (not `system.activationScripts`), ensuring:
- Files are created with correct user ownership (not root)
- Cross-platform compatibility (no `system.activationScripts` on darwin)
- Ordering guarantee: home-manager runs activation scripts after `home.file` links are placed, so the inclusion hook in the declarative config exists before the mutable file is seeded

On activation, if the mutable path doesn't exist, seed from `state/<prog>.conf` if present, otherwise create empty. Never overwrite existing mutable files.

**Override ordering**: Mutable always wins. The inclusion hook is positioned so the mutable file's values take precedence. `rebuild + override` has the same behavior as `override + rebuild`.

### Sync storage

```
state/
  <prog>.conf           — versioned snapshots of mutable overlays (committed to git)
  .hashes               — last-synced content hash per program (gitignored, local-only)
  .ancestors/
    <prog>.conf         — last-synced content per program, for 3-way merge (gitignored, local-only)
  .gitignore            — ignores .hashes and .ancestors/
  theme-override.nix    — current theme lock (committed to git)
```

When no ancestor exists in `state/.ancestors/<prog>.conf` (e.g., first sync), `state/<prog>.conf` is used as the ancestor. This unifies the code path — always three-way merge via `git merge-file`, the ancestor source just varies.

---

## Subcommands

### `nxc info`

System summary from the evaluated flake config.

```
Host: gustavo-Desktop
System: x86_64-linux / NixOS 26.05
WM: Hyprland | DM: sddm
Theme: tokyonight-moon

Services: 12 active    (nxc info --services)
TCP ports: 22, 80, 443
UDP ports: 41641, 21027, 22000

System packages: 47    (nxc info --packages)
Home packages: 123     (nxc info --packages --home)
```

On darwin, NixOS-specific lines (WM, DM, ports) are omitted; darwin-specific info (homebrew casks, system defaults) is shown instead.

**Implementation**: `nix eval --json .#configData."$HOST"` → cache to `~/.local/state/nxc/last-info.json` → `jq` formatting. Fields with `null` values are omitted from output.

**Flags**:
- `--json` — raw JSON output
- `--cached` — read last cached result (instant, no nix eval)
- `--packages [--home] [--search <term>]` — list/search packages, paged
- `--services` — list services, paged

**Deferred**: `--live` (query running system) and `--diff` (semantic diff between evaluated and running config) deferred to post-v1.

### `nxc mut status`

Overview of all registered programs and their mutable state.

```
PROGRAM     OVERRIDE   SYNC
hyprland    active     disk-changed
nvim        empty      clean
waybar      active     clean
ghostty     empty      clean
```

**Implementation**: Read registry JSON from `~/.local/state/nxc/registry.json`. For each program: check if mutable file exists and is non-empty, hash disk file and `state/<prog>.conf`, compare against `state/.hashes` to determine sync status.

**Sync statuses**: clean, disk-changed, state-changed, conflict, missing.

### `nxc mut show [prog]`

Display mutable overlay contents.

- `nxc mut show` — all non-empty mutable overlays with headers per program
- `nxc mut show <prog>` — single program's overlay
- If file empty or missing, say so explicitly

### `nxc mut edit <prog>`

Open mutable overlay in `$EDITOR` with seeding.

1. Look up `mutablePath` from registry
2. If file doesn't exist:
   - If `state/<prog>.conf` exists: show contents, prompt "Seed from state/? [Y/n/q]"
     - Y: copy as seed
     - n: create empty
     - q: abort entire edit
   - Otherwise: create empty
3. Open `$EDITOR "$mutablePath"`
4. After editor closes: if file changed and program has `reloadCmd`, prompt "Reload <prog>? [Y/n]"

### `nxc mut reset <prog>`

Wipe all mutable state for a program.

1. Show what will be deleted (mutable file, `state/<prog>.conf`, hash entry, ancestor)
2. Prompt "Reset <prog>? This removes all mutable state. [y/N]" (default No — destructive action)
3. On confirm: delete mutable file, `state/<prog>.conf`, hash entry from `state/.hashes`, ancestor from `state/.ancestors/<prog>.conf`
4. If program has `reloadCmd`, prompt to reload (program reverts to pure declarative config)

### `nxc mut sync`

Bidirectional sync between disk and `state/` for all programs.

For each registered program:
1. Hash disk file, hash `state/<prog>.conf`, read stored hash from `state/.hashes`
2. Skip if clean (both match stored hash)
3. Show three-way diff via `git merge-file`:
   - Ancestor: `state/.ancestors/<prog>.conf` if exists, otherwise `state/<prog>.conf`
   - If neither exists, use empty file (only on very first sync before any state exists)
4. Prompt per case:
   - **disk-changed**: "Disk has changes. Copy to state/? [Y/n/s]" (s = show diff again)
   - **state-changed**: "State/ has changes. Copy to disk? [Y/n/s]"
   - **conflict**: "Both changed. Take [d]isk / [s]tate / [m]erge / s[k]ip?"
     - merge: open `$EDITOR` with `git merge-file` output (conflict markers)
5. After each confirmed action: update `state/.hashes` and `state/.ancestors/<prog>.conf`

**Diff direction**: always `old → new` from the unchanged side's perspective.

**Pre-rebuild hook**: `nxc mut sync` can run before `nh os build/switch` via shell alias or wrapper. Not forced — skipping it is safe, just means stale snapshots.

### `nxc health`

Config hygiene check.

1. Run `statix check` — count warnings/errors
2. Run `deadnix` — count unused bindings
3. Run `nxc mut status` — flag stale overrides (mutable file mtime > `NXC_STALE_DAYS` days, default 7, configurable via env var in `.envrc` or shell)
4. Summary output:

```
Lint: 3 warnings (statix), 1 unused binding (deadnix)
Mutable: 2 active overrides, 1 stale (hyprland: 12 days)
```

- `--verbose` shows full linter output
- Exit code: 0 if warnings only, 1 if errors. `--strict` flag treats warnings as errors.

### `nxc theme set <name>`

Hot-swap theme colors without rebuild.

1. Look up theme in pre-rendered `themes.json` manifest
2. Prompt: "Apply <name> to hyprland, waybar, ghostty? [Y/n]"
3. For each program with a `themeTemplate`: find or create the `# --- nxc:theme start/end ---` section in the mutable file, replace its contents with the rendered colors. Content outside markers is untouched.
4. Fire each program's `reloadCmd`

### `nxc theme current`

Show active theme and detect drift.

1. Read the nxc:theme sections from mutable color files, hash their semantic content (color values only, stripped of markers and whitespace)
2. Compare hash against all entries in `themes.json` (also hashed the same way)
3. If a known theme matches: print its name
4. If no match: print "custom" (colors have been manually edited)
5. Compare runtime theme against Nix-declared theme (from evaluated config). If they differ, show both:
   ```
   Runtime: catppuccin-mocha
   Built:   tokyonight-moon (rebuild needed to fully apply)
   ```
   This makes the split-brain state visible — programs that bake colors at build time (Stylix, GTK) still use the built theme, while programs with mutable overlays use the runtime theme.

### `nxc theme lock`

Make current hot theme the declarative default.

1. Determine current theme (via `nxc theme current` logic)
2. Write theme name to `state/theme-override.nix`
3. The variables module reads this file if present, overriding the hardcoded theme value
4. Print confirmation: "Theme locked to <name>. Rebuild to make permanent."
5. Next rebuild picks up the new theme as the declarative default

### `nxc theme reset`

Restore Nix-declared theme colors.

1. Read the Nix-declared theme from variables (ignoring `state/theme-override.nix`)
2. Re-render that theme's colors to all mutable paths (replacing nxc:theme sections)
3. Fire reload commands
4. Delete `state/theme-override.nix` if present

---

## File layout

```
pkgs/nxc/
  default.nix          — Nix package definition (wraps the script)
  nxc.sh               — entry point, arg parsing, dispatch
  lib/
    info.sh            — nxc info implementation
    mut.sh             — nxc mut implementation
    theme.sh           — nxc theme implementation
    health.sh          — nxc health implementation
  queries/
    default.nix        — composes all query modules
    networking.nix
    packages.nix
    services.nix
    theme.nix
    system.nix

modules/mutable/
  default.nix          — program registry + activation logic (inclusion hooks, seeding)
  theme.nix            — theme hotswap layer (themeTemplate, manifest generation)

state/
  .gitignore           — ignores .hashes, .ancestors/
  .hashes              — last-synced content hashes (gitignored, local-only)
  .ancestors/          — last-synced content for 3-way merge (gitignored, local-only)
  theme-override.nix   — theme lock file (committed)
  <prog>.conf          — mutable overlay snapshots (committed)
```

## Dependencies

All available in the devShell or NixOS system:
- `bash`, `jq`, `git` (for `merge-file`), `nix` (for `eval`)
- `statix`, `deadnix` (for `health`)
- `$EDITOR` (for `edit`, `sync` merge)

## Deferred (post-v1)

- `nxc info --live` — query running system via systemctl / /run/current-system
- `nxc info --diff` — semantic diff between evaluated config and running system
- `nxc deps <module>` — module dependency graph
- `nxc size [module]` — closure size attribution
- `nxc history` — semantic changelog across rebuilds
- `nxc secrets` — sops/agenix audit
- `nxc test <module>` — single-module VM test
- `nxc pin` / `nxc diff --since <pin>` — config snapshots
- `nxc search <term>` — cross-module + evaluated config search
- `nxc mut diff <prog>` — per-program semantic diff against declarative base
- `nxc mut consolidate [--assist] <prog>` — merge mutable state into Nix (LLM-assisted mode needs Phase 9)
- `--serve` output mode (web UI / TUI)
- `nxc mut` menu-based editing UX
- Activation-time JSON generation for zero-overhead `nxc info`
- `nxc ai` — multi-provider AI CLI. Designed; spec in [`nxc-ai-design.md`](./nxc-ai-design.md).
