# Source: https://gitlab.com/fazzi/nixohess/-/blob/main/modules/services/nvidia_oc.nix?ref_type=heads
{
  sysModule =
    {
      config,
      lib,
      ...
    }:
    let
      inherit (lib)
        mkEnableOption
        mkOption
        types
        mkIf
        ;
      cfg = config.cfg.services.vmagent;
    in
    {
      options.cfg.services.vmagent = {
        enable = mkEnableOption "vmagent";
        remoteWriteUrl = mkOption {
          type = types.str;
        };
        username = mkOption {
          type = types.nullOr types.str;
          default = null;
        };
        passwordFile = mkOption {
          type = types.nullOr types.str;
          default = null;
        };
      };

      config = mkIf cfg.enable {
        services.vmagent = {
          enable = true;
          extraArgs = [ "-httpListenAddr=''" ];
          remoteWrite = {
            url = cfg.remoteWriteUrl;
            basicAuthUsername = cfg.username;
            basicAuthPasswordFile = cfg.passwordFile;
          };
          prometheusConfig = {
            scrape_configs = [
              {
                job_name = "node-exporter";
                scrape_interval = "60s";
                static_configs = [
                  {
                    targets = [ "127.0.0.1:9100" ];
                    labels.instance = config.networking.hostName;
                  }
                ];
              }
            ];
          };
        };

        services.prometheus.exporters.node = {
          enable = true;
          port = 9100;
          enabledCollectors = [ "systemd" ];
        };
      };
    };
}
