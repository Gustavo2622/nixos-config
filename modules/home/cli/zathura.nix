{
  pkgs,
  ...
}: {
  programs.zathura = {
    enable = true;
    options = {
      selection-clipboard = "clipboard";
      recolor = true;
      recolor-keephue = true;
    };
  };
}
