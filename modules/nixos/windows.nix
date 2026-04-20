# Enables NTFS kernel support for Windows partition interoperability.
# Mount configuration is commented out pending user setup.
_: {
  boot.supportedFilesystems = [
    "ntfs"
  ];

  # Mount windows fs at /mnt/windows on boot as RW
  #    fileSystems."/mnt/windows" =
  #      { device = "/dev/sdb2";
  #        fsType = "ntfs-3g";
  #        options = [ "rw" "uid=1000" ];
  #      };
}
