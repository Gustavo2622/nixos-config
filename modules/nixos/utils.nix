# System utility packages: git, perf, udisks2, wget, moreutils, difftastic,
# and mergiraf (structured merge driver).
{
  pkgs,
  config,
  ...
}: {
  environment.systemPackages = with pkgs; [
    git
    perf
    udisks2
    wget
    moreutils
    difftastic
    mergiraf
    ripgrep
    claude-code
  ];
}
