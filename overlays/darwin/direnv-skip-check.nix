# direnv checkPhase deadlocks on macOS — skip tests
final: prev: {
  direnv = prev.direnv.overrideAttrs (old: {
    doCheck = false;
  });
}
