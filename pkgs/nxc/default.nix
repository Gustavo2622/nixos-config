# nxc — NixOS Config Utility package
# Wraps the shell script with build-time constants and runtime dependencies.
#
# All lib scripts are concatenated into a single file at build time,
# which lets shellcheck see all definitions and usages together.
{
  lib,
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
  nxc-sandbox = callPackage ../nxc-sandbox {};

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
    runtimeInputs = [jq fzf coreutils findutils gnused diffutils git statix deadnix nxc-sandbox];
    text = scriptText;
  }
