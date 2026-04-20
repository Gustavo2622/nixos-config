# Installs 25+ font packages (JetBrains Mono, Noto, Fira Code, Font Awesome,
# Material Icons, Nerd Fonts, etc.) and enables fontconfig.
{pkgs, ...}: {
  fonts = {
    packages = with pkgs; [
      dejavu_fonts
      fira-code
      fira-code-symbols
      font-awesome
      hackgen-nf-font
      ibm-plex
      inter
      jetbrains-mono
      material-icons
      maple-mono.NF
      minecraftia
      nerd-fonts.fira-code
      nerd-fonts.im-writing
      nerd-fonts.blex-mono
      nerd-fonts.iosevka
      nerd-fonts.iosevka-term
      nerd-fonts.jetbrains-mono
      noto-fonts
      noto-fonts-color-emoji
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-monochrome-emoji
      powerline-fonts
      roboto
      roboto-mono
      symbola
      terminus_font
    ];
    fontDir.enable = true;
    fontconfig.enable = true;
  };
}
