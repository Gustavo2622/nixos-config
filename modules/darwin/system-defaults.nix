# macOS system preferences (declarative via nix-darwin)
_: {
  system = {
    defaults = {
      NSGlobalDomain = {
        # Appearance
        AppleInterfaceStyle = "Dark";
        AppleShowAllExtensions = true;

        # Keyboard
        ApplePressAndHoldEnabled = false; # Enable key repeat
        InitialKeyRepeat = 15; # Fastest
        KeyRepeat = 2; # Fastest

        # Mouse / trackpad
        "com.apple.mouse.tapBehavior" = 1; # Tap to click

        # Sound
        "com.apple.sound.beep.feedback" = 0; # Disable beep

        # Text input
        NSAutomaticSpellingCorrectionEnabled = false;
        NSAutomaticCapitalizationEnabled = false;

        # Save
        NSDocumentSaveNewDocumentsToCloud = false;
      };

      dock = {
        autohide = false;
        show-recents = false;
        mru-spaces = false;
        minimize-to-application = true;
        orientation = "bottom";
        tilesize = 48;
        show-process-indicators = true;
      };

      finder = {
        AppleShowAllFiles = true;
        AppleShowAllExtensions = true;
        FXEnableExtensionChangeWarning = false;
        FXPreferredViewStyle = "Nlsv"; # List view
      };

      trackpad = {
        Clicking = true; # Tap to click
        TrackpadThreeFingerDrag = true;
      };

      screencapture = {
        location = "~/Screenshots";
      };

      screensaver = {
        askForPasswordDelay = 5;
      };

      # Keyboard modifier: Caps Lock → Control
      # hidutil property --set '{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":0x700000039,"HIDKeyboardModifierMappingDst":0x7000000E0}]}'
      CustomUserPreferences = {
        "com.apple.desktopservices" = {
          DSDontWriteNetworkStores = true;
          DSDontWriteUSBStores = true;
        };
        # Disable Ctrl+Space input source switching (conflicts with nvim C-space)
        "com.apple.symbolichotkeys" = {
          AppleSymbolicHotKeys = {
            # 60 = "Select the previous input source" (Ctrl+Space)
            "60" = {enabled = false;};
            # 61 = "Select next source in input menu" (Ctrl+Alt+Space)
            "61" = {enabled = false;};
          };
        };
      };

      WindowManager = {
        StandardHideDesktopIcons = true;
      };
    };

    keyboard = {
      enableKeyMapping = true;
      remapCapsLockToControl = true;
    };

    # Activate after applying
    activationScripts.postActivation.text = ''
      # Create Screenshots directory if it doesn't exist
      mkdir -p ~/Screenshots
    '';
  };

  security.pam.services.sudo_local.touchIdAuth = true;
}
