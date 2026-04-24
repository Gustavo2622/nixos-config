# Home-manager entry point — linux host (imports shared + linux modules)
# Darwin entry point will import ../home/darwin instead.
{...}: {
  imports = [
    ./linux
    ../mutable
  ];
}
