# Zsh Aliases & Keybinds

Sourced from `modules/home/zsh/default.nix`.

---

## Shell Aliases

| Alias | Expands to | Purpose |
|-------|-----------|---------|
| `v` | `nvim` | Open Neovim |
| `sv` | `sudo nvim` | Open Neovim as root |
| `c` | `clear` | Clear terminal |
| `fr` | `nh os switch` | Rebuild and switch NixOS config |
| `fu` | `nh os switch --update` | Rebuild and switch, updating flake inputs |
| `ncg` | `nix-collect-garbage --delete-old && sudo nix-collect-garbage -d && sudo /run/current-system/bin/switch-to-configuration boot` | Full system garbage collection |
| `cat` | `bat` | Syntax-highlighted file viewer |
| `man` | `batman` | Colored man pages via bat |
| `diff` | `difftastic` | Structural diff tool |
| `nix-fmt-all` | `nix fmt ./` | Format all nix files in the repo |
| `urlencode` | python3 urllib.parse | URL-encode stdin |
| `urldecode` | python3 urllib.parse | URL-decode stdin |

---

## Shell Keybinds

Word and history navigation using `Alt` as modifier (set in `initContent`):

| Key | Action |
|-----|--------|
| `Alt+H` | Backward word |
| `Alt+J` | Down in history |
| `Alt+K` | Up in history |
| `Alt+L` | Forward word |
