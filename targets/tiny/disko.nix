{ ... }:

let
  bootdisk.id = "/dev/disk/by-id/mmc-DF4032_0x83432b3f";
in
{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = bootdisk.id;
        content = {
          type = "gpt";
          partitions = {
            boot = {
              size = "1M";
              type = "EF02";
            };
            ESP = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
  };
}
