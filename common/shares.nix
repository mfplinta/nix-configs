{
  hmModule =
    { ... }:
    {
      services.syncthing = {
        enable = true;
        tray.enable = true;
        overrideDevices = true;
        settings = {
          devices.mfp-nix-big = {
            addresses = [
              "tcp://syncthing.matheusplinta.com"
              "quic://syncthing.matheusplinta.com"
              "dynamic"
            ];
            id = "5YAHN4M-FLJ47V3-7CMIXZQ-ISX6TYZ-VA7EV4J-MT3CXOM-SORWTFK-QWHPXAK";
          };
        };
      };
    };

  sysModule =
    { pkgs, lib, ... }:
    {
      environment.sessionVariables = {
        STNODEFAULTFOLDER = 1;
      };

      fileSystems =
        let
          h = "/home/matheus";
          smbMountOptions = [
            "uid=1000,x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s,nofail,_netdev,credentials=/root/smb-secrets"
          ];
        in
        lib.genAttrs
          [
            "${h}/.cache/thumbnails"
            "${h}/.cache/kdenlive"
            "${h}/.config/session"
            "${h}/.local/share/kdenlive"
            "${h}/.local/share/stalefiles"
          ]
          (path: {
            device = "none";
            fsType = "ramfs";
            options = [
              "rw"
              "user"
              "mode=1777"
            ];
          })
        //
          lib.genAttrs
            [
              "/mnt/smb/mfp_stuff"
              "/mnt/smb/dap_stuff"
              "/mnt/smb/public"
            ]
            (path: {
              device = "//samba.arpa/${lib.last (lib.splitString "/" path)}";
              fsType = "cifs";
              options = smbMountOptions;
            });

      systemd.tmpfiles.rules = [
        "d /home/matheus/Shared 0755 matheus users -"
      ];

      services.samba = {
        enable = true;
        openFirewall = true;
        settings = {
          global = {
            workgroup = "WORKGROUP";
            security = "user";
            "acl allow execute always" = true;
            "hosts allow" = "10.0.1. 127.0.0.1 localhost 192.168.122.";
            # Symlink support
            "unix extensions" = "no";
            "follow symlinks" = "yes";
            "wide links" = "yes";
          };
          shared = {
            browseable = "yes";
            path = "/home/matheus/Shared";
            public = "no";
            "valid users" = [ "matheus" ];
            "read only" = "no";
            writable = "yes";
            printable = "no";
          };
        };
      };

      systemd.services.configure-smb-user = {
        enable = true;
        description = "Configure SMB users";
        after = [ "local-fs.target" ];
        path = [ pkgs.samba ];
        script = ''
          echo -ne "$(cat /root/matheus-smbpasswd)\n$(cat /root/matheus-smbpasswd)\n" | smbpasswd -a -s matheus
        '';
        wantedBy = [ "samba.target" ];
      };

      services.samba-wsdd = {
        enable = true;
        openFirewall = true;
      };

      environment.systemPackages = with pkgs; [
        cifs-utils
      ];
    };
}
