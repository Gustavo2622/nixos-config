{
  pkgs,
  neovim,
  ...
}: {
  home.packages =
    (with pkgs; [
      dockutil # Declarative dock management
      vim # Fallback editor
    ])
    ++ [neovim]; # NVF-compiled neovim

  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };
}
