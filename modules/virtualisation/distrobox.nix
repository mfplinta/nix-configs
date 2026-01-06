{
  sysModule =
    { config, lib, pkgs, ... }:
    let
      inherit (lib) mkIf mkEnableOption;
      cfg = config.cfg.virtualisation.distrobox;
    in
    {
      options.cfg.virtualisation.distrobox = {
        enable = mkEnableOption "distrobox";
      };

      config = mkIf cfg.enable {
        virtualisation.podman = {
          enable = true;
          dockerCompat = true;
        };

        environment.systemPackages = [ pkgs.distrobox ];
      };
    };
}
