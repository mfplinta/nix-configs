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
        metrics.enable = mkOption {
          type = types.bool;
          default = true;
        };
        metrics.port = mkOption {
          type = types.port;
          default = 9101;
        };
        config = mkOption {
          type = types.str;
          default = "";
        };
        environmentFile = mkOption {
          type = types.nullOr types.path;
          default = null;
        };
      };

      config = mkIf cfg.enable {
        services.caddy = {
          enable = true;
          package = pkgs.caddy.withPlugins {
            plugins = [
              "github.com/caddy-dns/cloudflare@v0.2.1"
              "github.com/caddyserver/replace-response@v0.0.0-20250618171559-80962887e4c6"
              "github.com/WeidiDeng/caddy-cloudflare-ip@v0.0.0-20231130002422-f53b62aa13cb"
            ];
            hash = "sha256-aiWiXXi/30BeIlizWtp+QvjediNe9wffWyd0T1yc+F8=";
          };
          environmentFile = cfg.environmentFile;
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

                                    		      (log) {
                                    		        log {
                                    			  output file /var/log/caddy/caddy-{args[0]}.log {
                                    			    roll_size 100MiB
                                    			    roll_keep 5
                                    			    roll_keep_for 100d
                        				            mode 644
                                    			  }
                                    			  format json
                                    			  level INFO
                                    			}
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
