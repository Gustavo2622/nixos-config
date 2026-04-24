# Bash shell: enables completion and defines aliases — sv (sudo nvim), fr (nh os switch),
# fu (update), ncg (nix gc), v (nvim), cat→bat, ..→cd ..
_: {
  programs.bash = {
    enable = false;
    enableCompletion = true;
    initExtra = ''
      if [ -f $HOME/.bashrc-personal ]; then
        source $HOME/.bashrc-personal
      fi
    '';
    shellAliases = {
      sv = "sudo nvim";
      fr = "nh os switch";
      fu = "nh os switch --update";
      ncg = "nix-collect-garbage --delete-old && sudo nix-collect-garbage -d && sudo /run/current-system/bin/switch-to-configuration boot";
      v = "nvim";
      cat = "bat";
      ".." = "cd ..";
    };
  };
}
