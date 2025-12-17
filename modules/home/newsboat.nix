{pkgs, ...}: {
  programs.newsboat = {
    enable = true;
    browser = "brave";
    extraConfig = ''
      auto-reload yes
      reload-time 30
      show-read-feeds no
      bind-key j down
      bind-key k up
      bind-key J next-feed articlelist
      bind-key K prev-feed articlelist
      bind-key G end
      bind-key g home
      bind-key l open
      bind-key h quit
    '';
  };
}
