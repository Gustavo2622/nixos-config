# Neovim Keymap Cheatsheet

Leader key: `<Space>`

## Pickers (mini.pick)
| Key | Action |
|-----|--------|
| `<leader>f` | Find files |
| `<leader>g` | Live grep |
| `<leader>b` | Buffer picker |
| `<leader>/` | Grep word under cursor |
| `<leader>h` | Help tags |
| `<leader>v` | Recent files (mini.visits) |
| `<leader>z` | Zoxide directory picker |
| `<leader>?` | Keymap explorer (searchable) |

**Picker search modifiers:** prefix `'` for exact match, `^` for case-sensitive. Combinable: `'^foo`.

## LSP & Diagnostics
| Key | Action |
|-----|--------|
| `gd` | Go to definition (Lspsaga) |
| `gy` | Go to type definition |
| `]d` | Next diagnostic |
| `[d` | Prev diagnostic |
| `]w` | Next warning |
| `<leader>lf` | Format buffer (explicit only) |

## Git
| Key | Action |
|-----|--------|
| `:G` | Fugitive status |
| `:Gblame` | Inline blame |
| `:Neogit` | Magit-like UI |
| `:DiffviewOpen` | Side-by-side diff |
| `:Diff3Way <ref>` | 3-panel vimdiff vs ref |

## Motion
| Key | Action |
|-----|--------|
| `<CR>` | Flash jump (label mode) |
| `<leader>r` | Flash remote operator |
| `]b` / `[b` | Next/prev buffer (mini.bracketed) |
| `]d` / `[d` | Next/prev diagnostic |

## Text Editing
| Key | Mode | Action |
|-----|------|--------|
| `gS` | n | Toggle single/multi-line (splitjoin) |
| `<C-M-j>` / `<C-M-k>` | n/v | Move line/selection down/up |
| `<C-M-h>` / `<C-M-l>` | n/v | Move line/selection left/right (indent) |
| `sa` / `sd` / `sr` | n | Add/delete/replace surround |

## Treesitter
| Key | Mode | Action |
|-----|------|--------|
| `<C-space>` | n | Init treesitter selection |
| `<C-space>` | v | Expand to parent node |
| `<C-S-space>` | v | Shrink to child node |
| `<leader>ti` | n | Inspect treesitter AST |

### Textobjects (use with `d`, `c`, `y`, `v` + `a`/`i`)
| Key | Object |
|-----|--------|
| `f` | Function |
| `c` | Class |
| `o` | Conditional (if/else) |
| `a` | Parameter/argument |
| `B` | Block |
| `q` | Quote (mini.ai default) |
| `b` | Brackets (mini.ai default) |

## Completion (Insert Mode)
| Key | Action |
|-----|--------|
| `<C-space>` | Show completions |
| `<Tab>` | Accept + snippet forward |
| `<S-Tab>` | Snippet backward |
| `<C-n>` / `<C-p>` | Next/prev item |
| `<C-e>` | Hide completions |
| `<CR>` | Insert newline (no auto-accept) |
| `<M-f>` / `<M-b>` | Scroll docs down/up |

## Terminal
| Key | Action |
|-----|--------|
| `<Esc>` | Exit terminal mode |

## Utility
| Key | Action |
|-----|--------|
| `<leader>u` | Toggle undotree |

## LaTeX (tex buffers only)
| Key | Mode | Action |
|-----|------|--------|
| `<leader>sn` | n | Next spell language |
| `<leader>sp` | n | Prev spell language |
| `<leader>lm` | n | Cycle snippet mode (off/basic/full) |
| `<M-l>` | i | Fix last spelling mistake |
| `<C-f>` | i | Create Inkscape figure |
| `<C-f>` | n | Edit Inkscape figure (Linux only) |

## Mini Plugins
| Plugin | What it does |
|--------|-------------|
| mini.ai | Extended textobjects (function, class, parameter, block, conditional) |
| mini.surround | Add/delete/replace surrounding pairs |
| mini.operators | Extended operators (evaluate, exchange, sort) |
| mini.bracketed | `]`/`[` navigation for buffers, diagnostics, etc. |
| mini.files | File explorer |
| mini.pick | Fuzzy finder (replaces telescope) |
| mini.indentscope | Animated current indent scope line |
| mini.visits | Frecent file tracking |
| mini.move | Move lines/selections (Ctrl+Alt+HJKL) |
| mini.splitjoin | Toggle single/multi-line (gS) |
| mini.statusline | Custom status bar with LaTeX indicators |
| mini.tabline | Buffer tab bar |
| mini.icons | File type icons |
