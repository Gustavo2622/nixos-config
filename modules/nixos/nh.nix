# nh Nix helper with /etc/nixos flake path, 7-day auto garbage collection
# (keep 5 generations); installs nix-output-monitor and nvd.
{pkgs, ...}: {
  programs.nh = {
    enable = true;
    clean = {
      enable = true;
      extraArgs = "--keep-since 7d --keep 5";
    };
    flake = "/etc/nixos";
  };

  environment.variables.NH_FLAKE = "/etc/nixos"; # for nh
  environment.systemPackages = with pkgs; [
    nix-output-monitor
    nvd
  ];
}
