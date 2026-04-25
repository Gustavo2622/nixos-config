{vars, ...}: {
  home = {
    username = vars.username;
    homeDirectory = "${vars.homePrefix}/${vars.username}";
    stateVersion = "24.05";
  };
}
