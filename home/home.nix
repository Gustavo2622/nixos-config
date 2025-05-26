{
  config,
  pkgs,
  inputs,
  outputs,
  lib,
  osConfig,
  ...
}: rec {
  imports = [
    ./desktop-monitor-cfg.nix
    ./hyprland
    ./waybar
    ./terminal.nix
    ./multimedia.nix
    ./productivity.nix
  ];

  home.username = "gustavo";
  home.homeDirectory = "/home/${home.username}";
  xdg.enable = true; # Sets XDG_CONFIG env vars

  # link the config file in cur dir to the specified location in home
  # home.file.".config/i3/wallpaper.jpg".source = ./wallpaper.jpg;

  # link all files in './scripts' to '~/.config/i3/scripts'
  # home.file.".config/i3/scripts" = {
  #   source = ./scripts;
  #   recursive = true; # link recursively
  #   executable = true; # make all files exec
  # };

  # encode the file content in nix configuration file directly
  # home.file.".xxx".text = ''
  #     xxx
  # '';

  # set cursor size and dpi
  xresources.properties = {
    "Xcursor.size" = lib.mkDefault 16;
  };

  xsession = lib.mkIf osConfig.awesomewm.enable {
    enable = true;
    windowManager.awesome = {
      enable = true;
      luaModules = with pkgs.luaPackages; [
        luarocks # package manager for lua modules
        luadbi-mysql # database abstraction
      ];
    };

    initExtra = ''
      dbus-update-activation-environment --systemd DISPLAY
      eval $(gnome-keyring-daemon --start --components=pkcs11,secrets,ssh)
      export SSH_AUTH_SOCK
    '';
  };
  xdg.configFile = {
    "awesome/rc.lua".text = builtins.readFile ./awesome/rc.lua;
  };
  desktop-monitor-cfg.enable = lib.mkIf osConfig.awesomewm.enable true;

  hyprland-hm-config.enable = osConfig.hyprlandwm.enable;
  waybar-hm-config.enable = osConfig.hyprlandwm.enable;

  programs.rofi = {
    enable = true;
    pass.enable = false; #  TODO: Set this up later
  };

  # TODO: Move above to module and make a flake for waypaper and swww

  # Packages that should be installed to the user profile
  home.packages =
    (with pkgs; [
      neofetch # Looks cool
      nnn # terminal file manager

      # archives
      p7zip
      unzip
      xz
      zip

      # utils
      clipboard-jh # Better, fancier clipboard
      eza # modern replacement for ls
      fd # Better search
      fzf # command line fuzzy find
      jq # command line json
      nushell # Better shell, in R U S T
      ripgrep # recursively search directories for a regex
      xclip
      xsel
      yazi # Rust file manager
      yq-go # yaml processor https://github.com/mikefarah/yq
      zoxide # smarter cd

      # networking tools
      aria2 # command line, lightweight, multiprotocol multi source download tool
      dnsutils # dig + nslookup
      ipcalc # ip address calculator
      iperf3
      ldns # drill, replacement for dig
      mtr # network diagnostics
      nmap # heheh
      socat # netcat but better

      # misc
      file
      gawk
      gnupg
      gnused
      gnutar
      tree
      which
      zstd

      # nix related
      alejandra # nix code formatting
      nix-output-monitor # provide 'nom' = nix + more output

      # productivity
      hugo # static site generator
      glow # markdown previewer for term

      btop # htop but better?
      iotop # io mon
      iftop # ip mon

      # sys call monitoring
      strace # sys call
      ltrace # lib call
      lsof # list open files

      # sys tools
      sysstat
      lm_sensors # sensors command
      ethtool
      pciutils # lspci
      usbutils # lsusb

      # Pretty fonts
      nerd-fonts.iosevka
      nerd-fonts.fira-code
      nerd-fonts.droid-sans-mono

      # Password Manager
      bitwarden-cli
      bitwarden-desktop
      bitwarden-menu
 
      # Web apps
      ferdium
    ])
    ++ [outputs.packages.${pkgs.system}.nvim];

  programs.git = {
    enable = true; # live and die by the protocol
    userName = "Gustavo Delerue";
    userEmail = "gxdelerue@proton.me";
    # userEmail = "gxdelerue@gmail.com";
  };

  programs.lazygit.enable = true;

  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    nix-direnv.enable = true;
  };

  ## Fix this
  services.gnome-keyring = {
    enable = true;
    components = ["pkcs11" "secrets" "ssh"];
  };

  fonts.fontconfig.enable = true;

  home.stateVersion = "24.11";

  # Let Home Manager do its thang
  programs.home-manager.enable = true;
}
