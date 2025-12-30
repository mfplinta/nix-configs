{
  sysModule =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib)
        mkEnableOption
        mkOption
        types
        mkIf
        ;
      cfg = config.cfg.services.caddy;
    in
    {
      options.cfg.services.caddy = {
        enable = mkEnableOption "caddy";
        config = mkOption {
          type = types.str;
        };
        metrics.enable = mkOption {
          type = types.bool;
          default = true;
        };
        metrics.port = mkOption {
          type = types.port;
          default = 9101;
        };
        crowdsec.enable = mkEnableOption "caddy crowdsec";
        crowdsec.apiKeyEnv = mkOption {
          type = types.path;
        };
        crowdsec.api_url = mkOption {
          type = types.str;
        };
        crowdsec.appsec_url = mkOption {
          type = types.nullOr types.str;
          default = null;
        };
        environmentFile = mkOption {
          type = types.nullOr types.path;
          default = null;
        };
        environmentFiles = mkOption {
          type = types.listOf types.path;
          default = [ ];
        };
      };

      config = mkIf cfg.enable {
        assertions = [
          {
            assertion = !(cfg.environmentFile != null && cfg.environmentFiles != [ ]);
            message = "Options environmentFile and environmentFiles are mutually exclusive.";
          }
        ];
        systemd.services.caddy.serviceConfig.EnvironmentFile =
          cfg.environmentFiles
          ++ lib.optional (cfg.environmentFile != null) cfg.environmentFile
          ++ lib.optional cfg.crowdsec.enable cfg.crowdsec.apiKeyEnv;
        services.caddy = {
          enable = true;
          package = pkgs.caddy.withPlugins {
            plugins = [
              "github.com/caddy-dns/cloudflare@v0.2.1"
              "github.com/caddyserver/replace-response@v0.0.0-20250618171559-80962887e4c6"
              "github.com/WeidiDeng/caddy-cloudflare-ip@v0.0.0-20231130002422-f53b62aa13cb"
              "github.com/hslatman/caddy-crowdsec-bouncer/http@v0.9.2"
              "github.com/hslatman/caddy-crowdsec-bouncer/appsec@v0.9.2"
              "github.com/hslatman/caddy-crowdsec-bouncer/layer4@v0.9.2"
            ];
            hash = "sha256-hK2SaUmy1xRwyLt0lybpoJ8h6FV9xbXc7qS8Qug/PEg=";
            doInstallCheck = false;
          };
          configFile = pkgs.writeText "Caddyfile" /* caddy */ ''
            (bot_block) {
              @botForbidden header_regexp User-Agent "(?i)AdsBot-Google|Amazonbot|anthropic-ai|Applebot|Applebot-Extended|AwarioRssBot|AwarioSmartBot|Bytespider|CCBot|ChatGPT|ChatGPT-User|Claude-Web|ClaudeBot|cohere-ai|DataForSeoBot|Diffbot|FacebookBot|Google-Extended|GPTBot|ImagesiftBot|magpie-crawler|omgili|Omgilibot|peer39_crawler|PerplexityBot|YouBot"
              handle @botForbidden {
                respond /* "Access denied" 403 {
                  close
                }
              }

              respond /robots.txt 200 {
                body "User-agent: *
                Disallow: /"
              }
            }

            (tunneled) {
              header_up X-Forwarded-For {http.request.header.CF-Connecting-IP}
            }

            {
              admin off
              ${if cfg.metrics.enable then "metrics" else ""}
              servers {
                trusted_proxies cloudflare {
                  interval 12h
                  timeout 15s
                }
              }
              log {
                output file /var/log/caddy/access.log {
                  roll_size 10MiB
                  roll_keep 5
                  roll_keep_for 30d
                  mode 644
                }
                format json
                level INFO
              }
              ${
                if cfg.crowdsec.enable then
                  ''
                                    order crowdsec first
                                    crowdsec {
                                      api_url ${cfg.crowdsec.api_url}
                                      api_key {env.CROWDSEC_API_KEY}
                                      ticker_interval 15s
                    		${
                        if (cfg.crowdsec.appsec_url != null) then
                          ''
                            		  appsec_url ${cfg.crowdsec.appsec_url}
                            		}
                            		order appsec after crowdsec
                            	        ''
                        else
                          "}"
                      }
                  ''
                else
                  ""
              }
            }

            ${
              if cfg.metrics.enable then
                ''
                  :${toString cfg.metrics.port} {
                    metrics
                  }
                ''
              else
                ""
            }
            ${cfg.config}
          '';
        };
      };
    };
}
