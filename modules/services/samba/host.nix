{
  sysModule =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.cfg.services.samba-host;
    in
    {
      options.cfg.services.samba-host = {
        enable = lib.mkEnableOption "samba-host";
        shares = lib.mkOption {
          default = { };
          type = lib.types.attrsOf (
            lib.types.submodule {
              options = {
                path = lib.mkOption { type = lib.types.path; };
                validUsers = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ ];
                };
                allowGuests = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                };
              };
            }
          );
        };

        users = lib.mkOption {
          default = { };
          type = lib.types.attrsOf (
            lib.types.submodule {
              options = {
                passwordFile = lib.mkOption { type = lib.types.path; };
              };
            }
          );
        };
      };

      config = lib.mkIf cfg.enable {
        services.samba = {
          enable = true;
          openFirewall = true;
          settings = {
            global = {
              workgroup = "WORKGROUP";
              security = "user";
              "acl allow execute always" = true;
              "hosts allow" = "10.0.1. 127.0.0.1 localhost 192.168.122.";
              "unix extensions" = "no";
              "follow symlinks" = "yes";
              "wide links" = "yes";
            };
          }
          // (lib.mapAttrs (name: value: {
            path = value.path;
            browseable = "yes";
            "read only" = "no";
            writable = "yes";
            printable = "no";
            "guest ok" = if value.allowGuests then "yes" else "no";
            "public" = if value.allowGuests then "yes" else "no";
            "valid users" = value.validUsers;
          }) cfg.shares);
        };

        services.samba-wsdd = {
          enable = true;
          openFirewall = true;
        };

        systemd.services = lib.mapAttrs' (
          name: userCfg:
          lib.nameValuePair "configure-smb-user-${name}" {
            description = "Configure SMB user: ${name}";
            after = [ "local-fs.target" ];
            path = [ pkgs.samba ];
            script = ''
              pw=$(cat ${userCfg.passwordFile})
              echo -ne "$pw\n$pw\n" | smbpasswd -a -s ${name}
            '';
            wantedBy = [ "samba.target" ];
          }
        ) cfg.users;

        environment.systemPackages = [ pkgs.cifs-utils ];
      };
    };
}
