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

        # Userns support
        users.groups.containers = { };
        users.users.containers = {
          group = "containers";
          isSystemUser = true;
          autoSubUidGidRange = true;
        };
      };
    };
}
