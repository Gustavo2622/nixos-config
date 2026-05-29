# nxc — NixOS Config Utility package
# Wraps the shell script with build-time constants and runtime dependencies.
#
# All lib scripts are concatenated into a single file at build time,
# which lets shellcheck see all definitions and usages together.
{
  lib,
  stdenv,
  writeShellApplication,
  callPackage,
  jq,
  fzf,
  coreutils,
  findutils,
  gnused,
  diffutils,
  git,
  statix,
  deadnix,
  # Build-time constants
  hostName,
  flakeRoot,
  themeName,
}: let
  # nxc-sandbox uses bubblewrap → Linux-only. On darwin, `nxc sandbox`/
  # `nxc claude` give a "command not found" runtime error (acceptable: those
  # subcommands aren't applicable there anyway).
  sandboxInputs = lib.optionals stdenv.hostPlatform.isLinux [
    (callPackage ../nxc-sandbox {})
  ];

  # nxc-mine is cross-platform (Python + httpx + psycopg) but currently only
  # talks to a Postgres on the desktop, so keep it Linux-side too for now.
  mineInputs = lib.optionals stdenv.hostPlatform.isLinux [
    (callPackage ../nxc-mine {})
  ];

  # Concatenate all script parts into one, with build-time constants baked in
  scriptText = ''
    # Build-time constants
    NXC_HOSTNAME="${hostName}"
    NXC_FLAKE_ROOT="${flakeRoot}"
    NXC_THEME_NAME="${themeName}"

    ${builtins.readFile ./lib/common.sh}
    ${builtins.readFile ./lib/info.sh}
    ${builtins.readFile ./lib/mut.sh}
    ${builtins.readFile ./lib/health.sh}
    ${builtins.readFile ./lib/theme.sh}
    ${builtins.readFile ./nxc-main.sh}
  '';
in
  writeShellApplication {
    name = "nxc";
    runtimeInputs = [jq fzf coreutils findutils gnused diffutils git statix deadnix] ++ sandboxInputs ++ mineInputs;
    text = scriptText;
  }
