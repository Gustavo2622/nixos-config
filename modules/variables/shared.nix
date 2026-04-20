# Shared variables: platform-agnostic, used on all hosts.
# CONSTRAINT: keep this attrset flat — no nesting. The per-host merge uses //
# (shallow), so nested attrs would be replaced entirely, not merged.
{
  gitUsername = "Gustavo Delerue";
  gitEmail = "gxdelerue@proton.me";
  terminal = "ghostty";
  browser = "brave";
  theme = "tokyonight-moon";

  # Fonts
  fontName = "Maple Mono NF";
  uiFontName = "JetBrainsMono Nerd Font Mono";
  stylixMonoFont = "JetBrains Mono";
  fallbackFont = "Symbola";
}
