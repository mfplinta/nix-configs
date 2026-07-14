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
    { config, lib, ... }:
    {
      environment.sessionVariables = {
        STNODEFAULTFOLDER = 1;
      };

      sops.secrets.workstation-smb_matheus_pwd = { };
      sops.secrets.nas-smb_matheus_pwd = { };

      fileSystems =
        let
          h = "/home/matheus";
        in
        lib.genAttrs
          [
            "${h}/.cache/thumbnails"
            "${h}/.cache/kdenlive"
            "${h}/.cache/kioexec/krun"
            "${h}/.config/session"
            "${h}/.local/share/kdenlive"
            "${h}/.local/share/stalefiles"
          ]
          (_: {
            device = "none";
            fsType = "ramfs";
            options = [
              "rw"
              "user"
              "mode=0700"
            ];
          });

      systemd.tmpfiles.rules = [
        "d /home/matheus/.cache 0700 matheus users -"
        "d /home/matheus/.cache/kioexec 0700 matheus users -"
        "d /home/matheus/.cache/kioexec/krun 0700 matheus users -"
        "d /home/matheus/.cache/kdenlive 0700 matheus users -"
        "d /home/matheus/.cache/thumbnails 0700 matheus users -"
        "d /home/matheus/.config 0700 matheus users -"
        "d /home/matheus/.config/session 0700 matheus users -"
        "d /home/matheus/.local/share 0700 matheus users -"
        "d /home/matheus/.local/share/kdenlive 0700 matheus users -"
        "d /home/matheus/.local/share/stalefiles 0700 matheus users -"
        "d /home/matheus/Shared 0755 matheus users -"
      ];

      cfg.services.samba-host = {
        enable = true;
        shares = {
          shared = {
            path = "/home/matheus/Shared";
            validUsers = [ "matheus" ];
            allowGuests = false;
          };
        };
        users.matheus.passwordFile = config.sops.secrets.workstation-smb_matheus_pwd.path;
      };

      cfg.services.samba-client =
        let
          username = "matheus";
          passwordFile = config.sops.secrets.nas-smb_matheus_pwd.path;
        in
        {
          "/mnt/smb/mfp_stuff" = {
            inherit username passwordFile;
            remotePath = "//samba.arpa/mfp_stuff";
          };
          "/mnt/smb/dap_stuff" = {
            inherit username passwordFile;
            remotePath = "//samba.arpa/dap_stuff";
          };
          "/mnt/smb/public" = {
            inherit username passwordFile;
            remotePath = "//samba.arpa/public";
          };
        };
    };
}
