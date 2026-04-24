{
  lib,
  theme,
  ...
}: let
  accent = "#${theme.base0D}";
  muted = "#${theme.base03}";
in {
  programs.lazygit = {
    enable = true;
    settings = lib.mkForce {
      disableStartupPopups = true;
      notARepository = "skip";
      promptToReturnFromSubprocess = false;
      update.method = "never";
      git = {
        commit.signOff = true;
        parseEmoji = true;
      };
      gui = {
        theme = {
          activeBorderColor = [accent "bold"];
          inactiveBorderColor = [muted];
        };
        showListFooter = false;
        showRandomTip = true;
        showCommandLog = false;
        showBottomLine = false;
        nerdFontsVersion = "3";
      };
    };
  };
}
