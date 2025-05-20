{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-Micron_3400_MTFDKBA512TFH_21283060575A";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "1024M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "crypted";
                settings.allowDiscards = true;
                passwordFile = "/tmp/secret.key";
                content = {
                  type = "filesystem";
                  format = "f2fs";
                  mountpoint = "/";
                  extraArgs = [
                    "-O"
                    "extra_attr,inode_checksum,sb_checksum,compression"
                  ];
                  mountOptions = [
                    "compress_algorithm=zstd:6,compress_chksum,atgc,gc_merge,lazytime,nodiscard"
                  ];
                };
              };
            };
          };
        };
      };
    };
  };
}
