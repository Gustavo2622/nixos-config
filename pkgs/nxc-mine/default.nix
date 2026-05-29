# nxc-mine — research/content mining framework.
# First slice covers `nxc mine research <init|ingest|papers>` (arXiv + IACR
# ePrint metadata ingest). Embeddings, extraction, dedup, web reader land in
# subsequent slices per docs/research-mining-design.md.
#
# Packaging: `python3.withPackages` builds a Python env containing our deps,
# then `makeWrapper` invokes that env's python with the entry script as args
# and PYTHONPATH set to our lib dir (where store/config/sources live).
# buildPythonApplication's `format = "other"` does NOT propagate deps to
# PYTHONPATH automatically; this explicit pattern avoids that gotcha.
{
  stdenvNoCC,
  python3,
  makeWrapper,
  lib,
}: let
  pyEnv = python3.withPackages (ps: with ps; [httpx psycopg]);
in
  stdenvNoCC.mkDerivation {
    pname = "nxc-mine";
    version = "0.2.0";

    src = lib.fileset.toSource {
      root = ./.;
      fileset = lib.fileset.unions [
        ./nxc_mine.py
        ./store.py
        ./config.py
        ./schema.sql
        ./ollama.py
        ./extract.py
        ./dedup.py
        ./sources
      ];
    };

    nativeBuildInputs = [makeWrapper];

    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib/nxc-mine/sources
      install -m644 store.py config.py schema.sql ollama.py extract.py dedup.py \
        $out/lib/nxc-mine/
      install -m644 sources/*.py $out/lib/nxc-mine/sources/
      install -Dm755 nxc_mine.py $out/lib/nxc-mine/nxc_mine.py
      makeWrapper ${pyEnv}/bin/python3 $out/bin/nxc-mine \
        --add-flags $out/lib/nxc-mine/nxc_mine.py \
        --prefix PYTHONPATH : $out/lib/nxc-mine
      runHook postInstall
    '';

    meta = {
      description = "Research/content mining framework for nxc";
      mainProgram = "nxc-mine";
    };
  }
