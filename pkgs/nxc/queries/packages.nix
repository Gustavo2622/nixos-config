# Query: packages — system and home package lists + counts
{
  config,
  lib,
}: {
  system = let
    sysPkgs = lib.attrByPath ["environment" "systemPackages"] [] config;
  in {
    count = builtins.length sysPkgs;
    names = map (p: p.name or p.pname or "unknown") sysPkgs;
  };
}
