# NixOS Desktop Configuration

Single-host NixOS flake config for `gustavo-Desktop` (AMD desktop, Hyprland, nixos-unstable).
Multi-host support (nix-darwin) is planned — see `docs/multi-host-plan.md`.

## Commands

```bash
# Rebuild NixOS system
nh os switch -q /etc/nixos

# Rebuild home-manager only
nh home switch -q /etc/nixos

# Format nix files (alejandra)
nix fmt

# Update flake inputs
nix flake update

# Build neovim standalone
nix build .#neovim
```

## Architecture

- `flake.nix` — single entry point; one host (`gustavo-Desktop`), one home config
- `modules/variables.nix` — central switchable options (terminal, display manager, bar, animations, fonts). This is a `rec {}` attrset, not a NixOS module — imported with `import ../variables.nix`
- `modules/nixos/` — system-level modules (hardware, services, WM, networking)
- `modules/nixos/default.nix` — aggregator; conditionally imports display manager based on `variables.nix`
- `modules/home/` — home-manager modules (apps, shell, desktop, editors)
- `modules/nvim.nix` — Neovim config via NVF framework (separate from home modules, consumed directly by flake)
- `overlays/` — package patches (anki libxshmfence fix, bleeding-edge ltrace)
- `pkgs/` — custom packages:
  - `nxc/` — shell-script dispatcher (`info`/`mut`/`theme`/`health`/`sandbox`/`claude`/`mine`)
  - `nxc-sandbox/` — bubblewrap-based sandbox runner (Linux-only)
  - `nxc-mine/` — research-paper mining: Postgres+pgvector store, arXiv + IACR ePrint ingest, bge-m3 embeddings + qwen2.5:14b extraction, Textual TUI review queue
- `secrets/` — sops-nix encrypted secrets. `server.yaml` (desktop server-side: caddy deSEC token, vaultwarden/searxng/paperless secrets) is encrypted to both the host age key at `/var/lib/sops-nix/key.txt` and the user's personal age key. `secrets.yaml` is personal-only.
- `docs/` — design docs: `nxc-design.md`, `nxc-ai-design.md`, `research-mining-design.md`, `nvim-keymap.md`, `multi-host-plan.md`

## Key Patterns

- **Variables-driven config**: switchable options live in `variables.nix` — modules import it with `let vars = import ../variables.nix;` and branch on values. Variables are annotated with `[shared]`, `[linux-only]`, `[per-host]` scope tags for the future multi-host split.
- **Conditional imports**: display manager module selected at import time in `modules/nixos/default.nix` via if/else on `vars.displayManager`
- **Stylix theming**: system-wide with explicit disables for custom-styled apps (waybar, rofi, hyprland, ghostty) in `modules/nixos/stylix.nix`
- **NVF for Neovim**: declarative neovim built via `nvf.lib.neovimConfiguration`, not standard home-manager programs.neovim — lives at `modules/nvim.nix` (not in `editors/`) because it's consumed by the flake directly

## Gotchas

- `variables.nix` is a plain attrset with `rec {}`, NOT a NixOS/home-manager module — don't add `{ config, ... }:` function wrappers
- The formatter is `alejandra`, not `nixpkgs-fmt` — run `nix fmt` before committing
- Neovim is built as a flake package and passed via `specialArgs`, not configured inline in home-manager
- Overlays are composed in `overlays/default.nix` and applied globally via `nixpkgs.overlays` in the flake output
- `modules/home/default.nix` uses `rec {}` at the top level — be aware of evaluation order if adding bindings
- Always use `nh` with `-q` flag — without it, `nix-output-monitor` produces verbose decorative output that is hard to parse programmatically
- `xdg.nix` configures Hyprland-specific portals — it is linux-only despite the generic name
- `python.nix` contains a waybar Weather.py wrapper — linux-specific dependency in an otherwise cross-platform module
- `user.nix` (home) hardcodes `/home/${username}` — needs parameterization for darwin (`/Users/`)
- `overlays/bleeding-edge.nix` is marked DEPRECATED — check if ltrace is in nixos-unstable yet
