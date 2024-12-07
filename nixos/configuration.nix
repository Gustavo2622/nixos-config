# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  lib,
  config,
  pkgs,
  inputs,
  outputs,
  home-manager,
  ...
} @ args: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    # Include graphics card configuration
    ./nvidia.nix
    # NixOS hardware imports
    inputs.hardware.nixosModules.common-gpu-nvidia-nonprime
    inputs.hardware.nixosModules.common-pc-ssd
    inputs.hardware.nixosModules.common-cpu-intel-cpu-only
    inputs.hardware.nixosModules.common-pc

    home-manager.nixosModules.home-manager

    ./awesomewm.nix
    ./hyprlandwm.nix
    # autorandr settings for x11
    # ../modules/config/desktop-monitor-cfg.nix
  ];

  config = {
    # Nix config
    nix = {
      package = pkgs.nixVersions.latest;
      extraOptions = ''
        experimental-features = nix-command flakes
      '';
      settings = {
        substituters = ["https://hyprland.cachix.org"];
        trusted-public-keys = ["hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="];
      };
    };

    home-manager.useGlobalPkgs = true;
    home-manager.extraSpecialArgs = {inherit inputs outputs;}; # Extra params to home-manager
    home-manager.backupFileExtension = "bck";

    home-manager.users.gustavo = import args.hmConfig;

    # Bootloader.
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    networking = {
      hostName = "gustavo-Desktop"; # Define your hostname.
      useDHCP = lib.mkOverride 1200 true;
    };
    # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

    # Configure network proxy if necessary
    # networking.proxy.default = "http://user:password@proxy:port/";
    # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

    # Enable networking
    networking.networkmanager.enable = true;

    # Set your time zone.
    time.timeZone = "Europe/Lisbon";

    # Select internationalisation properties.
    i18n.defaultLocale = "en_US.UTF-8";

    i18n.extraLocaleSettings = {
      LC_ADDRESS = "pt_PT.UTF-8";
      LC_IDENTIFICATION = "pt_PT.UTF-8";
      LC_MEASUREMENT = "pt_PT.UTF-8";
      LC_MONETARY = "pt_PT.UTF-8";
      LC_NAME = "pt_PT.UTF-8";
      LC_NUMERIC = "pt_PT.UTF-8";
      LC_PAPER = "pt_PT.UTF-8";
      LC_TELEPHONE = "pt_PT.UTF-8";
      LC_TIME = "pt_PT.UTF-8";
    };

    # Enable the X11 windowing system.
    # services.xserver.enable = true;

    # Enable the GNOME Desktop Environment.
    # services.xserver.displayManager.gdm.enable = true;
    # services.xserver.desktopManager.gnome.enable = true;

    # desktop-monitor-cfg.enable = true;

    # Configure keymap in X11
    services.xserver.xkb = {
      layout = "us";
      variant = "";
      options = "ctrl:swapcaps";
    };

    console.useXkbConfig = true;

    # Enable CUPS to print documents.
    services.printing.enable = true;

    # Enable sound with pipewire.
    hardware.pulseaudio.enable = false;
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;

      # Session/Policy manager
      wireplumber.enable = true;

      # If you want to use JACK applications, uncomment this
      #jack.enable = true;

      # use the example session manager (no others are packaged yet so this is enabled by default,
      # no need to redefine it in your config for now)
      #media-session.enable = true;
    };

    # Enable touchpad support (enabled default in most desktopManager).
    # services.xserver.libinput.enable = true;

    # Define a user account. Don't forget to set a password with ‘passwd’.
    users.users.gustavo = {
      isNormalUser = true;
      description = "Gustavo";
      extraGroups = ["networkmanager" "wheel"];
      packages = with pkgs; [
        #  thunderbird
      ];
    };

    # Enable automatic login for the user.
    # services.displayManager.autoLogin.enable = true;
    # services.displayManager.autoLogin.user = "gustavo";

    # Workaround for GNOME autologin: https://github.com/NixOS/nixpkgs/issues/103746#issuecomment-945091229
    # systemd.services."getty@tty1".enable = false;
    # systemd.services."autovt@tty1".enable = false;
    systemd.services.nix-daemon.environment.TMPDIR = "/var/tmp";

    # Install firefox.
    programs.firefox.enable = true;

    # Allow unfree packages
    nixpkgs.config.allowUnfree = true;

    # Enable Flaken and nix-commands features
    nix.settings.experimental-features = ["nix-command" "flakes"];

    # List packages installed in system profile. To search, run:
    # $ nix search wget
    environment.systemPackages = with pkgs; [
      vim
      zenith-nvidia
      neovim
      git
      kitty # for hyprland
      nh
      nix-output-monitor
      nvd
      wget
    ];
    environment.variables.EDITOR = "nvim";
    environment.variables.FLAKE = "/etc/nixos"; # for nh

    fonts.fontDir.enable = true;

    # Some programs need SUID wrappers, can be configured further or are
    # started in user sessions.
    # programs.mtr.enable = true;
    # programs.gnupg.agent = {
    #   enable = true;
    #   enableSSHSupport = true;
    # };

    # List services that you want to enable:

    # Enable xdg desktop portals to allow flatpak
    xdg.portal.enable = true;
    xdg.portal.extraPortals = with pkgs; [xdg-desktop-portal-gtk];

    xdg.portal.config = {
      common = {
        default = [
          "gtk"
        ];
      };
    };

    # Enable flatpak
    services.flatpak.enable = true;

    # Enable gnome keyring
    services.gnome.gnome-keyring.enable = true;
    programs.seahorse.enable = true;
    security.pam.services.sddm.enableGnomeKeyring = true;

    # Enable the OpenSSH daemon.
    # services.openssh.enable = true;

    # Open ports in the firewall.
    # networking.firewall.allowedTCPPorts = [ ... ];
    # networking.firewall.allowedUDPPorts = [ ... ];
    # Or disable the firewall altogether.
    # networking.firewall.enable = false;

    # This value determines the NixOS release from which the default
    # settings for stateful data, like file locations and database versions
    # on your system were taken. It‘s perfectly fine and recommended to leave
    # this value at the release version of the first install of this system.
    # Before changing this value read the documentation for this option
    # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
    system.stateVersion = "24.05"; # Did you read the comment?

    # Configure system * s t y l e *
    stylix = {
      enable = true;
      image = ../Wallpapers/PinkPurpleHaze.jpg;

      fonts = {
        monospace = {
          package = pkgs.nerd-fonts.fira-code;
          name = "Fira Code Nerd Fonts Monospace";
        };
        sizes = {
          terminal = 16;
        };
      };
      polarity = "dark";
    };

    awesomewm.enable = lib.mkDefault true;

    specialisation = {
      hyprland = {
        configuration = {
          awesomewm.enable = lib.mkOverride 950 false;
          hyprlandwm.enable = lib.mkOverride 950 true;
        };
      };
    };
  };
}
