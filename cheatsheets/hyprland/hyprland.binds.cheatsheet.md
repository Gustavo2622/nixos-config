# Hyprland Keybindings

## Conventions
- `$mod` = Super (Windows/Meta key)
- Arrows and `hjkl` are interchangeable for movement
- Bindings marked **[noctalia]** only apply when `barChoice = "noctalia"` in variables.nix
- Bindings marked **[rofi]** only apply when `barChoice != "noctalia"`

---

## 🚀 Launchers & Overview

| Key | Action |
|-----|--------|
| `$mod+D` | App launcher — Noctalia IPC **[noctalia]** or rofi **[rofi]** |
| `$mod+TAB` | QuickShell overview toggle |
| `$mod+CTRL+D` | Toggle dock |
| `$mod+K` | Keybinds viewer (qs-keybinds) |
| `$mod+CTRL+C` | Cheatsheets viewer (qs-cheatsheets) |
| `$mod+SHIFT+K` | Legacy keybinds menu (rofi) |

---

## 🖥️ Terminal & Files

| Key | Action |
|-----|--------|
| `$mod+Return` | Open terminal (set by `terminal` in variables.nix) |
| `$mod+SHIFT+T` | Dropdown terminal (pypr scratchpad) |
| `$mod+Y` | File manager (yazi in kitty) |
| `$mod+T` | Thunar file manager |

---

## 🌐 Apps & Utilities

| Key | Action |
|-----|--------|
| `$mod+W` | Web browser (set by `browser` in variables.nix) |
| `$mod+SHIFT+D` | Discord |
| `$mod+I` | VS Code |
| `$mod+G` | GIMP |
| `$mod+O` | OBS Studio |
| `$mod+ALT+M` | Audio control (pavucontrol) |
| `$mod+ALT+W` | Web search |
| `$mod+SHIFT+W` | Wallpaper setter (qs-wallpapers-apply) / Noctalia wallpaper **[noctalia]** |
| `$mod+E` | Emoji picker |
| `$mod+ALT+C` | Color picker (hyprpicker) |
| `$mod+SHIFT+N` | Reset notifications (swaync) |

---

## 📋 Clipboard

| Key | Action |
|-----|--------|
| `$mod+V` | Noctalia clipboard **[noctalia]** / cliphist rofi menu **[rofi]** |

---

## 🖼️ Screenshots

| Key | Action |
|-----|--------|
| `$mod+S` | Screenshot → swappy editor |
| `$mod+CTRL+S` | Screenshot full output → ~/Pictures/ScreenShots |
| `$mod+SHIFT+S` | Screenshot active window → ~/Pictures/ScreenShots |
| `$mod+ALT+S` | Screenshot region → ~/Pictures/ScreenShots |

---

## 🪟 Window Management

| Key | Action |
|-----|--------|
| `$mod+Q` | Kill active window |
| `$mod+F` | Fullscreen / maximize |
| `$mod+SHIFT+F` | Toggle floating |
| `$mod+ALT+F` | All windows float |
| `$mod+P` | Pseudo tile |
| `$mod+SHIFT+I` | Toggle split direction |
| `$mod+SHIFT+C` | Exit Hyprland |

---

## 🔀 Focus Movement

| Key | Action |
|-----|--------|
| `$mod+←/→/↑/↓` | Move focus |
| `$mod+h/j/k/l` | Move focus (vi-style) |
| `ALT+Tab` | Cycle next window |

---

## ↔️ Move & Swap Windows

| Key | Action |
|-----|--------|
| `$mod+SHIFT+←/→/↑/↓` | Move window |
| `$mod+SHIFT+h/j/k/l` | Move window (vi-style) |
| `$mod+ALT+←/→/↑/↓` | Swap window |

---

## 🗂️ Workspaces

| Key | Action |
|-----|--------|
| `$mod+1–9, 0` | Switch to workspace 1–10 |
| `$mod+SHIFT+1–9, 0` | Move window to workspace 1–10 |
| `$mod+CTRL+→/←` | Next / previous workspace |
| `$mod+ScrollDown/Up` | Next / previous workspace |
| `$mod+SPACE` | Toggle special workspace |
| `$mod+SHIFT+SPACE` | Move window to special workspace |

---

## 🔊 Media & Brightness

| Key | Action |
|-----|--------|
| `XF86AudioRaiseVolume` | Volume +5% (wpctl) |
| `XF86AudioLowerVolume` | Volume -5% (wpctl) |
| `XF86AudioMute` | Toggle mute |
| `XF86AudioPlay/Pause` | Play/pause (playerctl) |
| `XF86AudioNext/Prev` | Next/previous track |
| `XF86MonBrightnessUp/Down` | Brightness ±5% (brightnessctl) |

---

## 🖱️ Mouse Bindings

| Key | Action |
|-----|--------|
| `$mod+LMB` | Move window |
| `$mod+RMB` | Resize window |

---

## 🌙 Noctalia-only Bindings

> Only active when `barChoice = "noctalia"` in variables.nix

| Key | Action |
|-----|--------|
| `$mod+M` | Toggle notification history |
| `$mod+X` | Power menu |
| `$mod+C` | Control center |
| `$mod+ALT+P` / `$mod+SHIFT+,` | Settings |
| `$mod+ALT+L` | Lock screen + suspend |
| `$mod+CTRL+R` | Screen recorder |
