# Mutable state management module.
# Declares which programs have mutable overlays, generates the registry JSON,
# and seeds mutable fragment directories on activation.
#
# This is a home-manager module — mutable files live in ~/.local/state/mutable/<prog>/
# and the registry at ~/.local/state/nxc/registry.json.
#
# Programs are split into shared/linux/darwin registries and composed per-host.
# Each program can be individually disabled via the `enable` field.
#
# Fragment ordering convention:
#   00-09: tool-managed (theme, etc.)
#   10-89: user fragments
#   90-99: debug/temporary overrides
#
# Precedence types:
#   last-wins  — later fragments override same-key settings (Hyprland, Ghostty, Zellij)
#   sequential — fragments execute in order, side effects accumulate (Nvim Lua, CSS)
{
  config,
  lib,
  pkgs,
  vars,
  nxcPkg,
  ...
}: let
  homeDir = config.home.homeDirectory;
  mutableDir = "${homeDir}/.local/state/mutable";
  nxcStateDir = "${homeDir}/.local/state/nxc";
  flakeRoot = "/etc/nixos";
  isLinux = pkgs.stdenv.isLinux;
  isDarwin = pkgs.stdenv.isDarwin;

  # Shared programs — available on all platforms
  sharedPrograms = {
    nvim = {
      enable = true;
      mutableDir = "${mutableDir}/nvim";
      fileExtension = "lua";
      inclusionMethod = "dofile-dir";
      precedence = "sequential";
      reloadCmd = null;
      declaredConfigPath = null;
      commentStart = "--";
      commentEnd = "";
    };
    ghostty = {
      enable = true;
      mutableDir = "${mutableDir}/ghostty";
      fileExtension = "conf";
      inclusionMethod = "config-file-dir";
      precedence = "last-wins";
      reloadCmd = "pkill -USR2 ghostty";
      declaredConfigPath = null;
      commentStart = "#";
      commentEnd = "";
    };
    # Zellij deferred — KDL has no include/source mechanism.
    # TODO: wrapper script approach (option 2) when needed.
  };

  # Linux-only programs
  linuxPrograms = {
    hyprland = {
      enable = true;
      mutableDir = "${mutableDir}/hyprland";
      fileExtension = "conf";
      inclusionMethod = "source-glob";
      precedence = "last-wins";
      reloadCmd = "hyprctl reload";
      declaredConfigPath = "${homeDir}/.config/hypr/hyprland.conf";
      commentStart = "#";
      commentEnd = "";
    };
    waybar = {
      enable = true;
      mutableDir = "${mutableDir}/waybar";
      fileExtension = "css";
      inclusionMethod = "css-import-dir";
      precedence = "sequential";
      reloadCmd = "pkill -SIGUSR2 waybar";
      declaredConfigPath = null;
      commentStart = "/*";
      commentEnd = "*/";
    };
  };

  # Darwin-only programs (populated when darwin modules are added)
  darwinPrograms = {
  };

  # Compose: shared + platform-specific, filtered by enable
  allPrograms = let
    platformPrograms =
      if isLinux
      then linuxPrograms
      else if isDarwin
      then darwinPrograms
      else {};
    merged = sharedPrograms // platformPrograms;
  in
    lib.filterAttrs (_: prog: prog.enable) merged;

  # Strip the `enable` field before serializing — the script doesn't need it
  registryPrograms =
    lib.mapAttrs (_: prog: builtins.removeAttrs prog ["enable"]) allPrograms;

  registryJson = builtins.toJSON registryPrograms;
in {
  imports = [./theme.nix];

  # Add nxc to user's PATH
  home.packages = [nxcPkg];

  # Zsh completions for nxc
  home.file.".local/share/zsh/site-functions/_nxc".source = ../../pkgs/nxc/completions/_nxc;
  programs.zsh.initContent = lib.mkOrder 550 ''
    fpath+=("$HOME/.local/share/zsh/site-functions")
  '';
  # Generate registry JSON on activation
  home.activation.nxcRegistry = lib.hm.dag.entryAfter ["writeBoundary"] ''
    mkdir -p "${nxcStateDir}"
    cat > "${nxcStateDir}/registry.json" << 'REGISTRY_EOF'
    ${registryJson}
    REGISTRY_EOF
  '';

  # Seed mutable fragment directories on activation (never overwrite existing)
  home.activation.nxcSeedMutable = lib.hm.dag.entryAfter ["nxcRegistry"] ''
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: prog: ''
        mkdir -p "${prog.mutableDir}"
        # Seed from state/ snapshots if the directory is empty
        if [ -z "$(ls -A "${prog.mutableDir}" 2>/dev/null)" ]; then
          if [ -d "${flakeRoot}/state/${name}" ]; then
            cp "${flakeRoot}/state/${name}"/* "${prog.mutableDir}/" 2>/dev/null || true
          fi
        fi
        # Ensure at least one file exists so glob-based source directives don't fail
        touch -a "${prog.mutableDir}/00-nxc-placeholder.${prog.fileExtension}"
      '')
      registryPrograms)}
  '';
}
