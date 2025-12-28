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
        extraScrapeConfigs = mkOption {
          type = types.listOf types.attrs;
          default = [ ];
          description = "List of additional prometheus scrape configurations.";
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
            ] ++ cfg.extraScrapeConfigs;
          };
        };

        services.prometheus.exporters.node = {
          enable = true;
          listenAddress = "127.0.0.1";
          port = 9100;
          enabledCollectors = [ "systemd" ];
        };
      };
    };
}
