final: prev: {
  anki-bin = prev.anki-bin.overrideAttrs (_old: {
    postInstall = ''
      wrapProgram "$out/bin/anki" --suffix LD_LOAD_PATH "${final.libxshmfence}/lib/"
    '';
  });
}
