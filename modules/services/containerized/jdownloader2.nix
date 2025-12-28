{
  hmModule =
    {
      sysConfig,
      config,
      lib,
      ...
    }:
    let
      inherit (lib) mkEnableOption mkIf;
      cfg = config.cfg.services.jdownloader2;
    in
    {
      options.cfg.services.jdownloader2 = {
        enable = mkEnableOption "jdownloader2";
      };

      config = mkIf cfg.enable {
        assertions = [
          {
            assertion = sysConfig.cfg.virtualisation.quadlet.enable;
            message = "Quadlet must be enabled to use the jdownloader2 container.";
          }
        ];

        systemd.user.tmpfiles.rules = [
          "d %h/Downloads/JD 0755 matheus users -"
          "d %h/.config/containers/jdownloader2 0755 matheus users -"
        ];

        virtualisation.quadlet.containers.jdownloader2 = {
          autoStart = true;
          containerConfig = {
            image = "jlesage/jdownloader-2";
            volumes = [
              "%h/Downloads/JD:/output"
              "%h/.config/containers/jdownloader2:/config"
            ];
            publishPorts = [ "5800:5800" ];
          };
        };
      };
    };
}
