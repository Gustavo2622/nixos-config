# Compatibility shim: erlang-ls was archived upstream and removed from nixpkgs.
# The upstream-recommended replacement is erlang-language-platform (ELP).
# This overlay aliases erlang-ls -> erlang-language-platform so that derivations
# referencing pkgs.erlang-ls continue to work.
#
# Long-term: fix the reference to use erlang-language-platform directly and remove this overlay.
final: _prev: {
  erlang-ls = final.erlang-language-platform;
}
