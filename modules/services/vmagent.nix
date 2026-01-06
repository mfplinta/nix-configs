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
        logs.enable = mkEnableOption "vlagent";
        logs.remoteWriteUrl = mkOption {
          type = types.str;
        };
        logs.username = mkOption {
          type = types.nullOr types.str;
          default = null;
        };
        logs.passwordFile = mkOption {
          type = types.nullOr types.str;
          default = null;
        };
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
              {
                job_name = "process-exporter";
                static_configs = [
                  {
                    targets = [ "127.0.0.1:9101" ];
                    labels.instance = config.networking.hostName;
                  }
                ];
              }
            ]
            ++ cfg.extraScrapeConfigs;
          };
        };

        services.prometheus.exporters = {
          node = {
            enable = true;
            listenAddress = "127.0.0.1";
            port = 9100;
            enabledCollectors = [ "systemd" ];
          };
          process = {
            enable = true;
            listenAddress = "127.0.0.1";
            port = 9101;
            settings = {
              process_names = [
                # Remove nix store path from process
                #{ name = "{{.Matches.Wrapped}} {{ .Matches.Args }}"; cmdline = [ "^/nix/store[^ ]*/(?P<Wrapped>[^ /]*) (?P<Args>.*)" ]; }
                {
                  name = "{{.ExeBase}}";
                  cmdline = [ ".+" ];
                }

              ];
            };
          };
        };

        services.vlagent = {
          enable = true;
          extraArgs = [ "-httpListenAddr='127.0.0.1:9429'" ];
          remoteWrite = {
            url = cfg.remoteWriteUrl;
            basicAuthUsername = cfg.logs.username;
            basicAuthPasswordFile = cfg.logs.passwordFile;
          };
        };
      };
    };
}
