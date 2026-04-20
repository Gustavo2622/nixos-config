# Sets EDITOR and VISUAL to nvim system-wide; provides both vim and the
# nvf-compiled neovim package.
{
  pkgs,
  neovim,
  ...
}: {
  environment.variables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };
  environment.systemPackages =
    (with pkgs; [
      vim
    ])
    ++ [neovim];
}
