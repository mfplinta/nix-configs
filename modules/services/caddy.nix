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
	enableMetrics = mkOption {
	  type = types.bool;
	  default = true;
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
            ];
            hash = "sha256-zBhsiXgA4CAJgjgpHpLo27CFO5tF0x8YKbLvnUawmck=";
          };
          environmentFile = cfg.environmentFile;
          configFile =
            pkgs.writeText "Caddyfile" /* caddy */ ''
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
			${if cfg.enableMetrics then "metrics" else ""}
		      }

                      ${if cfg.enableMetrics then ''
		      :9101 {
		        metrics
		      }
		      '' else ""}

		      ${cfg.config}
              	      '';
        };
      };
    };
}
