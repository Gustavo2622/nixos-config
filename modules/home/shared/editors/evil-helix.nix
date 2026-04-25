{
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs;
    [
      evil-helix
      cmake-language-server
      # jsonnet-language-server
      luaformatter
      lua-language-server
      taplo
    nil
    # jq-lsp
    vscode-langservers-extracted
    bash-language-server
    awk-language-server
    vscode-extensions.llvm-vs-code-extensions.vscode-clangd
    clang-tools
    docker-compose-language-service
    docker-compose
    docker-language-server
    # typescript-language-server
  ]
  ++ lib.optionals pkgs.stdenv.isLinux [
    marksman # dotnet-based, hangs on darwin
  ];

  home.file.".config/helix/config.toml".text = ''
    theme = "catpuccin_mocha"
    # theme = "ao"

    [editor]
    evil = true
    end-of-line-diagnostics = "hint"
    auto-pairs = true
    mouse = true
    middle-click-paste = true
    shell = ["zsh", "-c"]
    line-number = "absolute"
    auto-completion = true
    path-completion = true
    auto-info = true
    color-modes = true
    popup-border = "all"
    clipboard-provider = "${
      if pkgs.stdenv.isLinux
      then "wayland"
      else "default"
    }"
    indent-heuristic = "hybrid"

    [editor.statusline]
    left = ["mode", "spinner"]
    center = ["file-absolute-path", "total-line-numbers", "read-only-indicator", "file-modification-indicator"]
    right = ["diagnostics", "selections", "position", "file-encoding", "file-line-ending", "file-type"]
    separator = "|"
    mode.normal = "NORMAL"
    mode.insert = "INSERT"
    mode.select = "SELECT"

    [editor.lsp]
    enable = true
    display-messages = true
    display-progress-messages = true

    [editor.inline-diagnostics]
    cursor-line = "hint"
    other-lines = "hint"
  '';
}
