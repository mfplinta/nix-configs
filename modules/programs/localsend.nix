{
  hmModule =
    { sysConfig, pkgs, lib, ... }:
    let
      inherit (lib) mkIf;
      cfg = sysConfig.cfg.programs.localsend;
    in
    {
      config = mkIf cfg.enable {
        home.packages = [
          pkgs.localsend
        ];
      };
    };

  sysModule =
    { config, lib, ... }:
    let
      inherit (lib) mkIf mkEnableOption;
      cfg = config.cfg.programs.localsend;
    in
    {
      options.cfg.programs.localsend = {
        enable = mkEnableOption "localsend";
      };

      config = mkIf cfg.enable {
        networking.firewall.allowedTCPPorts = [ 53317 ];
        networking.firewall.allowedUDPPorts = [ 53317 ];
      };
    };
}