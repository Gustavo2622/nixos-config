# Neovim Cheatsheet

> Configuration via **nvf** (NotAShelf's Vim Framework) — fully declarative Nix.
> All settings live in `modules/nvim.nix`; Lua runtime files are under `dots/nvim/lua/`.

---

## Framework

| Item | Detail |
|------|--------|
| Plugin manager | nvf (Nix-native, no lazy.nvim/packer) |
| Config entry | `modules/nvim.nix` |
| Lua runtime | `dots/nvim/lua/` (loaded via `additionalRuntimePaths`) |
| Rebuild | `nh os switch` to apply changes to `nvim.nix` |

---

## File Navigation

| Key | Action |
|-----|--------|
| `<leader>ff` | Find files (Telescope) |
| `<leader>fg` | Live grep (Telescope) |
| `<leader>fb` | Buffers (Telescope) |
| `<space>` | Open mini.files explorer |
| `<leader>mp` | mini.pick file picker |

---

## Motion

| Key | Action |
|-----|--------|
| `<CR>` | flash-nvim jump (label characters on screen) |
| `s` | flash-nvim search motion |

---

## LSP

Languages configured: **nix**, **lua**, **rust**, **ocaml**

| Key | Action |
|-----|--------|
| `gd` | Go to definition |
| `gr` | References |
| `K` | Hover documentation |
| `<leader>ca` | Code action |
| `<leader>rn` | Rename symbol |
| `<leader>xx` | Trouble diagnostics list |
| `[d` / `]d` | Previous / next diagnostic |

OCaml LSP: `ocamllsp` resolved from the active devshell PATH via direnv.

---

## Formatting

Formatting is **never automatic**. Use `<leader>lf` to format on demand.

| Key | Action |
|-----|--------|
| `<leader>lf` | Format current buffer (conform.nvim, async) |

- nix → `nixpkgs-fmt` | lua → `stylua` | rust → `rustfmt`
- ocaml → `ocamlformat` from active devshell PATH (direnv)

---

## Autocomplete

blink-cmp with ripgrep source. Tab / S-Tab to navigate, Enter to confirm.

---

## Git

| Command / Key | Action |
|---------------|--------|
| `<leader>gs` | Neogit status |
| `<leader>gd` | Diffview current file |
| `:DiffviewOpen` | Full repo diff (all files) |
| `:DiffviewOpen HEAD~1` | Diff against parent commit |
| `:DiffviewOpen main..HEAD` | 2-panel: main → HEAD |
| `:DiffviewOpen HEAD...main` | 2-panel anchored at merge base |
| `:DiffviewFileHistory %` | Commit log for current file |
| `:Diff3Way <ref>` | **3-panel: current \| merge-base \| `<ref>`** |
| `:diffoff \| only` | Close diff view |
| `]h` / `[h` | Next / prev hunk (gitsigns) |
| `<leader>hs` | Stage hunk |
| `<leader>hr` | Reset hunk |
| `:Git` | vim-fugitive command window |

---

## Terminal

| Key | Action |
|-----|--------|
| `<leader>tt` | Toggle terminal (toggleterm) |
| `<Esc>` | Exit terminal mode |

---

## Text Objects (mini.ai + treesitter)

| Object | Description |
|--------|-------------|
| `af` / `if` | Around / inside function |
| `ac` / `ic` | Around / inside class |
| `aa` / `ia` | mini.ai argument |
| `as` / `is` | mini.ai sentence |

## Surround (mini.surround)

| Key | Action |
|-----|--------|
| `sa` | Add surround |
| `sd` | Delete surround |
| `sr` | Replace surround |

---

## UI

| Key / Command | Action |
|---------------|--------|
| `<leader>u` | Toggle undotree |
| `za` | Toggle fold (nvim-ufo) |
| `zR` | Open all folds |
| `zM` | Close all folds |

---

## LaTeX / Castel Workflow

Powered by **vimtex** (compilation + SyncTeX) and **LuaSnip** (context-aware snippets).
PDF viewer: **Zathura** (SyncTeX bidirectional sync).

### Snippet modes

`<leader>lm` cycles: **off** → **basic** → **full** → off (startup default: **full**)

The current mode is shown in the statusline when a `.tex` file is open.

| Mode | Snippets active |
|------|-----------------|
| `off` | None |
| `basic` | ~20 essential: math entry, fractions, environments, super/subscripts, common symbols |
| `full` | All of basic + Greek letters, number sets, large operators, delimiters, auto-subscript, visual fraction |

### Basic snippets (mode ≥ basic)

| Trigger | Expansion | Context |
|---------|-----------|---------|
| `mk` | `$...$` | outside math |
| `dm` | `\[...\]` (display) | anywhere |
| `//` | `\frac{}{}` | math |
| `beg` | `\begin{env}...\end{env}` (mirrored) | anywhere |
| `ali` | `\begin{align*}...\end{align*}` | anywhere |
| `eq` | `\begin{equation}...\end{equation}` | anywhere |
| `item` | itemize environment | anywhere |
| `enum` | enumerate environment | anywhere |
| `sr` | `^2` | math |
| `cb` | `^3` | math |
| `__` | `_{}` | math |
| `hat` / `bar` / `vec` | `\hat{}` / `\overline{}` / `\vec{}` | math |
| `->` | `\to` | math |
| `...` | `\ldots` | math |
| `xx` | `\times` | math |
| `ooo` | `\infty` | math |
| `incpkg` | Full `\incfig` preamble block | tex |

### Full-only snippets (mode = full)

- **Greek** (math): `a`→`\alpha`, `b`→`\beta`, `g`→`\gamma`, ... `w`→`\omega`
- **Number sets**: `RR`→`\mathbb{R}`, `ZZ`, `NN`, `QQ`, `CC`
- **Operators**: `sum`, `int`, `lim`, `dif`→`\mathrm{d}`
- **Relations**: `!=`→`\neq`, `~=`→`\approx`, `==`→`\equiv`, `<=`→`\le`, `>=`→`\ge`, `**`→`\cdot`
- **Delimiters**: `lr(`, `lr[`, `lr{`, `lr|`, `lra` (angle brackets)
- **More postfix**: `dot`, `ddot`, `tilde`, `und`
- **Auto-subscript**: `a1` → `a_1` (any letter + digit, math only)
- **Visual fraction**: select numerator, press `/` → `\frac{VISUAL}{}`

### Spell check

`<leader>sn` / `<leader>sp` — cycle language forward / backward

Languages: `en_us` → `pt` → `fr` → `de` → `en_us,pt,fr,de` (all)

Active language shown in statusline. Add more to `spell_langs` in `dots/nvim/lua/latex-setup/init.lua`.

`<M-l>` (insert mode) — fix last spelling mistake without leaving insert mode

### Inkscape figures

| Key | Action |
|-----|--------|
| `<C-f>` (insert) | Prompt for name → create SVG → insert `\incfig{name}` → open Inkscape |
| `<C-f>` (normal) | Open rofi picker to edit an existing figure |

Required preamble (insert with `incpkg` snippet):
```latex
\usepackage{import}
\usepackage{xifthen}
\usepackage{pdfpages}
\usepackage{transparent}
\newcommand{\incfig}[1]{%
    \def\svgwidth{\columnwidth}
    \import{./figures/}{#1.pdf_tex}
}
```

The `inkscape-figures watch` daemon runs as a **systemd user service** started automatically on login. When you save an SVG in Inkscape (`Ctrl+S`), it auto-exports to `figures/<name>.pdf` and `figures/<name>.pdf_tex` — no manual export dialog needed.

Check watcher status: `systemctl --user status inkscape-figures-watch`
