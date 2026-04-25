{
  pkgs,
  vars,
  ...
}: {
  users.users.${vars.username} = {
    home = "${vars.homePrefix}/${vars.username}";
    shell = pkgs.zsh;
  };
}
