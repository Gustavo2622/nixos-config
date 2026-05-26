# nxc-sandbox — bubblewrap-based sandboxing with TOML path rules
{
  python3Packages,
  bubblewrap,
  direnv,
  git,
  lib,
}:
python3Packages.buildPythonApplication {
  pname = "nxc-sandbox";
  version = "0.1.0";
  format = "other";

  # Only the script itself — keep test files, __pycache__, result symlink out of the store
  src = lib.fileset.toSource {
    root = ./.;
    fileset = ./nxc_sandbox.py;
  };

  propagatedBuildInputs = lib.optionals (! python3Packages.python.pkgs ? tomllib) [
    python3Packages.tomli
  ];

  # buildPythonApplication auto-wraps bin/ programs once (postFixup); don't wrap manually.
  installPhase = ''
    runHook preInstall
    install -Dm755 nxc_sandbox.py $out/bin/nxc-sandbox
    runHook postInstall
  '';

  makeWrapperArgs = [
    "--prefix PATH : ${lib.makeBinPath [bubblewrap direnv git]}"
  ];
}
