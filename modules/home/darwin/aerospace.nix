# Aerospace tiling window manager for macOS
# Keybind caveat: Alt+H/J/K/L conflicts with zellij normal-mode Alt+ binds
# over SSH. Zellij's modal pane/tab modes (plain H/J/K/L) still work fine.
# Revisit if this becomes a pain point.
{vars, ...}: {
  xdg.configFile."aerospace/aerospace.toml".text = ''
    # AeroSpace config — managed by nix, iterate via nxc mut later
    start-at-login = true
    after-login-command = []
    after-startup-command = []

    # Mouse follows focus
    on-focus-changed = ["move-mouse window-lazy-center"]

    # Normalizations
    enable-normalization-flatten-containers = true
    enable-normalization-opposite-orientation-for-nested-containers = true

    # Layout
    default-root-container-layout = "tiles"
    default-root-container-orientation = "auto"

    # Gaps
    [gaps]
    inner.horizontal = 8
    inner.vertical = 8
    outer.left = 8
    outer.bottom = 8
    outer.top = 8
    outer.right = 8

    # Main mode
    [mode.main.binding]
    # Focus
    alt-h = "focus left"
    alt-j = "focus down"
    alt-k = "focus up"
    alt-l = "focus right"

    # Move window
    alt-shift-h = "move left"
    alt-shift-j = "move down"
    alt-shift-k = "move up"
    alt-shift-l = "move right"

    # Workspaces
    alt-1 = "workspace 1"
    alt-2 = "workspace 2"
    alt-3 = "workspace 3"
    alt-4 = "workspace 4"
    alt-5 = "workspace 5"
    alt-6 = "workspace 6"
    alt-7 = "workspace 7"
    alt-8 = "workspace 8"
    alt-9 = "workspace 9"

    # Move window to workspace
    alt-shift-1 = "move-node-to-workspace 1"
    alt-shift-2 = "move-node-to-workspace 2"
    alt-shift-3 = "move-node-to-workspace 3"
    alt-shift-4 = "move-node-to-workspace 4"
    alt-shift-5 = "move-node-to-workspace 5"
    alt-shift-6 = "move-node-to-workspace 6"
    alt-shift-7 = "move-node-to-workspace 7"
    alt-shift-8 = "move-node-to-workspace 8"
    alt-shift-9 = "move-node-to-workspace 9"

    # Layout
    alt-f = "fullscreen"
    alt-shift-f = "layout floating tiling"
    alt-t = "layout tiles horizontal vertical"
    alt-shift-t = "layout accordion horizontal vertical"

    # Close
    alt-shift-q = "close"

    # Open terminal
    alt-enter = "exec-and-forget open -a Ghostty"

    # Resize mode
    alt-r = "mode resize"

    # Reload config
    alt-shift-r = "reload-config"

    # Resize mode
    [mode.resize.binding]
    h = "resize width -50"
    j = "resize height +50"
    k = "resize height -50"
    l = "resize width +50"
    escape = "mode main"
    enter = "mode main"
  '';
}
