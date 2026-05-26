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

  src = ./.;

  propagatedBuildInputs = lib.optionals (! python3Packages.python.pkgs ? tomllib) [
    python3Packages.tomli
  ];

  nativeBuildInputs = [python3Packages.wrapPython];

  installPhase = ''
    mkdir -p $out/bin
    cp nxc_sandbox.py $out/bin/nxc-sandbox
    chmod +x $out/bin/nxc-sandbox
    wrapPythonPrograms
  '';

  makeWrapperArgs = [
    "--prefix PATH : ${lib.makeBinPath [bubblewrap direnv git]}"
  ];
}
