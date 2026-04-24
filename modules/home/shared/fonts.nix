# Configures fontconfig to append a symbol fallback after the primary terminal font
# so codepoints absent from the primary (e.g. U+21A0–21A3 arrows, math, box-drawing)
# are served by the fallback. Works for all apps via fontconfig without per-terminal config.
{vars, ...}: {
  xdg.configFile."fontconfig/conf.d/99-symbol-fallback.conf".text = ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
    <fontconfig>
      <!-- Codepoints absent from ${vars.fontName} fall through to ${vars.fallbackFont} -->
      <match>
        <test name="family"><string>${vars.fontName}</string></test>
        <edit name="family" mode="append">
          <string>${vars.fallbackFont}</string>
        </edit>
      </match>
    </fontconfig>
  '';
}
