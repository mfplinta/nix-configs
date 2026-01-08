{
  sysModule =
    { config, lib, ... }:
    let
      inherit (lib) mkEnableOption mkIf;
      cfg = config.cfg.virtualisation.quadlet;
    in
    {
      options.cfg.virtualisation.quadlet = {
        enable = mkEnableOption "quadlet";
      };

      config = mkIf cfg.enable {
        virtualisation.quadlet.enable = true;
        virtualisation.quadlet.autoUpdate.enable = true;
        virtualisation.podman.defaultNetwork.settings.dns_enabled = true;

        # Userns support
        users.groups.containers = { };
        users.users.containers = {
          group = "containers";
          isSystemUser = true;
          subGidRanges = [
            {
              count = 16777216;
              startGid = 100000;
            }
          ];
          subUidRanges = [
            {
              count = 16777216;
              startUid = 100000;
            }
          ];
        };
      };
    };
}
