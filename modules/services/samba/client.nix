{
  sysModule =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.cfg.services.samba-client;

      commonOptions = [
        "uid=1000"
        "x-systemd.automount"
        "noauto"
        "x-systemd.idle-timeout=60"
        "x-systemd.device-timeout=5s"
        "x-systemd.mount-timeout=5s"
        "nofail"
        "_netdev"
      ];
    in
    {
      options.cfg.services.samba-client = lib.mkOption {
        default = { };
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              remotePath = lib.mkOption {
                type = lib.types.str;
                example = "//samba.arpa/public";
              };
              passwordFile = lib.mkOption {
                type = lib.types.path;
                description = "Path to a file containing ONLY the password.";
              };
              username = lib.mkOption {
                type = lib.types.str;
                default = "matheus";
              };
              domain = lib.mkOption {
                type = lib.types.str;
                default = "WORKGROUP";
              };
            };
          }
        );
      };

      config =
        let
          getSafeName = mountPoint: lib.replaceStrings [ "/" ] [ "-" ] (lib.removePrefix "/" mountPoint);
        in
        {
          systemd.tmpfiles.rules = [
            "d /mnt/smb 0755 root root -"
          ];

          fileSystems = lib.mapAttrs (mountPoint: shareCfg: {
            device = shareCfg.remotePath;
            fsType = "cifs";
            options = commonOptions ++ [
              "credentials=/run/smb-credentials/${getSafeName mountPoint}"
            ];
          }) cfg;

          systemd.services = lib.mapAttrs' (
            mountPoint: shareCfg:
            let
              safeName = getSafeName mountPoint;
            in
            lib.nameValuePair "prepare-smb-creds-${safeName}" {
              description = "Prepare Samba credentials for ${mountPoint}";
              before = [ "${lib.replaceStrings [ "/" ] [ "-" ] (lib.removePrefix "/" mountPoint)}.mount" ];
              wantedBy = [ "multi-user.target" ];
              script = ''
                mkdir -p /run/smb-credentials
                password=$(cat ${shareCfg.passwordFile})
                cat <<EOF > /run/smb-credentials/${safeName}
                username=${shareCfg.username}
                domain=${shareCfg.domain}
                password=$password
                EOF
                chmod 600 /run/smb-credentials/${safeName}
              '';
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
              };
            }
          ) cfg;

          environment.systemPackages = [ pkgs.cifs-utils ];
        };
    };
}
