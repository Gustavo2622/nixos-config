# Browser configurations: Firefox and qutebrowser enabled; Brave configured with
# uBlock Origin extension and WebRTC leak protection disabled.
{
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    firefox
    qutebrowser
  ];

  programs.chromium = {
    enable = true;
    package = pkgs.brave;
    extensions = [
      { id = "cjpalhdlnbpafiamejdnhcphjbkeiagm"; } # ublock origin
    ];
    commandLineArgs = [
      "--disable-features=WebRtcAllowInputVolumeAdjustment"
    ];
  };
}

