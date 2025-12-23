{
  pkgs,
  lib,
  config,
  sysImport,
  ...
}:

let
  hostConfig = config;
  addresses = {
    reverseProxy = {
      host = "192.168.100.10";
      local = "192.168.100.11";
    };
    monitoring = {
      host = "192.168.101.10";
      local = "192.168.101.11";
    };
    ws-blog = {
      host = "192.168.102.10";
      local = "192.168.102.11";
    };
    ws-ots = {
      host = "192.168.103.10";
      local = "192.168.103.11";
    };
    gitea = {
      host = "192.168.104.10";
      local = "192.168.104.11";
    };
    ws-mastermovement = {
      host = "192.168.105.10";
      local = "192.168.105.11";
    };
    vaultwarden = {
      host = "192.168.106.10";
      local = "192.168.106.11";
    };
    nextcloud = {
      host = "192.168.107.10";
      local = "192.168.107.11";
    };
  };
  websiteConfig =
    {
      appName,
      envFile,
      extra ? { },
    }:
    { ... }:
    let
      caddy-django-env =
        with pkgs.python3Packages;
        with pkgs;
        python3.withPackages (
          ps: with ps; [
            django
            gunicorn
            pillow
            django-markdownx
            whitenoise
            (django-imagekit ps)
            (django-turnstile ps)
          ]
        );
    in
    lib.mkMerge [
      {
        system.stateVersion = config.system.stateVersion;
        networking.firewall.enable = false;

        environment.systemPackages = with pkgs; [
          (writeShellApplication {
            name = "update-website";
            runtimeInputs = [
              git
              caddy-django-env
            ];
            text = ''
              set -e
              set -x
              cd /app/

              if [ "$USER" = "django" ]
              then
                git pull
                python manage.py collectstatic --noinput
              elif [ "$USER" = "root" ]
              then
                git config --global --add safe.directory '*'
                chown -R django:django .
                sudo -u django "$0" "$@"
                systemctl restart django-gunicorn.service
              else
                echo "Please run as sudo or django"
                exit 1
              fi
            '';
          })
        ];

        services.caddy = {
          enable = true;
          configFile = pkgs.writeText "Caddyfile" ''
            :8000 {
              encode gzip

              handle_path /media/* {
                root * /app/media
                file_server
              }

              handle {
                reverse_proxy 127.0.0.1:9000
              }
            }
          '';
        };

        systemd.tmpfiles.rules = [
          "d /app 0755 django django -"
        ];

        systemd.services.django-gunicorn = {
          description = "Gunicorn service for Django app";
          after = [
            "network.target"
            "systemd-tmpfiles-setup.service"
          ];
          wantedBy = [ "multi-user.target" ];
          environment.DJANGO_DEBUG = "False";
          serviceConfig = {
            Type = "simple";
            User = "django";
            Group = "django";
            WorkingDirectory = "/app";
            EnvironmentFile = [ envFile ];
            ExecStart = "${caddy-django-env}/bin/gunicorn --workers 3 --bind 127.0.0.1:9000 ${appName}.wsgi:application";
            Restart = "always";
          };
        };

        users.users.django = {
          isSystemUser = true;
          group = "django";
        };

        users.groups.django = { };
      }
      extra
    ];
in
{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix

    (sysImport ../../common/base.nix)
    (sysImport ../../common/server.nix)
  ];

  boot.kernelParams = [
    "net.ifnames=0"
    "boot.shell_on_fail"
    "panic=30"
    "boot.panic_on_fail"
  ];

  sops.defaultSopsFile = ./../../private/secrets.yaml;
  sops.age.keyFile = "/root/.config/sops/age/keys.txt";
  sops.secrets.cf_api_key = { };
  sops.secrets.cloudy-crowdsec_token = {
    mode = "0444";
  };
  sops.secrets.cloudy-http_auth_bcrypt = { };
  sops.secrets.cloudy-grafana_pwd = {
    mode = "0444";
  };
  sops.secrets.cloudy-blog_secretkey = { };
  sops.secrets.cloudy-ots_secretkey = { };
  sops.secrets.cloudy-ots_turnstile_sitekey = { };
  sops.secrets.cloudy-ots_turnstile_secret = { };
  sops.secrets.cloudy-mm_secretkey = { };
  sops.secrets.cloudy-mm_turnstile_sitekey = { };
  sops.secrets.cloudy-mm_turnstile_secret = { };
  sops.secrets.cloudy-nextcloud_admin = {
    mode = "0444";
  };
  sops.secrets.cloudy-nextcloud_onlyoffice_jwt = {
    mode = "0444";
  };
  sops.secrets.cloudy-nextcloud_onlyoffice_nonce = { };
  sops.secrets.cloudy-private_wg = {
    mode = "0444";
  };
  sops.secrets.cloudy-tmdb_api = { };
  sops.secrets.cloudy-fanart_api = { };
  sops.secrets.cloudy-tmdb_mongodb_uri = { };
  sops.templates.env_tmdb = {
    mode = "0444";
    content = ''
      TMDB_API=${config.sops.placeholder.cloudy-tmdb_api}
      FANART_API=${config.sops.placeholder.cloudy-fanart_api}
      MONGODB_URI=${config.sops.placeholder.cloudy-tmdb_mongodb_uri}
      HOST_NAME=https://tmdb-addon-stremio.matheusplinta.com
      PORT=1337
    '';
  };
  sops.templates.env_caddy = {
    mode = "0444";
    content = ''
      CF_API_KEY=${config.sops.placeholder.cf_api_key}
      HTTP_AUTH_PWD=${config.sops.placeholder.cloudy-http_auth_bcrypt}
    '';
  };
  sops.templates.env_blog = {
    mode = "0444";
    content = ''
      SECRET_KEY=${config.sops.placeholder.cloudy-blog_secretkey}
    '';
  };
  sops.templates.env_ots = {
    mode = "0444";
    content = ''
      SECRET_KEY=${config.sops.placeholder.cloudy-ots_secretkey}
      TURNSTILE_SITEKEY=${config.sops.placeholder.cloudy-ots_turnstile_sitekey}
      TURNSTILE_SECRET=${config.sops.placeholder.cloudy-ots_turnstile_secret}
    '';
  };
  sops.templates.env_mastermovement = {
    mode = "0444";
    content = ''
      SECRET_KEY=${config.sops.placeholder.cloudy-mm_secretkey}
      TURNSTILE_SITEKEY=${config.sops.placeholder.cloudy-mm_turnstile_sitekey}
      TURNSTILE_SECRET=${config.sops.placeholder.cloudy-mm_turnstile_secret}
    '';
  };
  sops.templates.nextcloud_nonce = {
    mode = "0444";
    content = ''
      set $secure_link_secret "${config.sops.placeholder.cloudy-nextcloud_onlyoffice_nonce}";
    '';
  };

  networking =
    let
      hostNic = "eth0";
    in
    {
      nftables.enable = true;
      useDHCP = false;
      interfaces = {
        "${hostNic}".ipv4.addresses = [
          {
            address = "10.0.0.104";
            prefixLength = 24;
          }
        ];
      };
      defaultGateway = {
        address = "10.0.0.1";
        interface = "eth0";
      };
      nameservers = [ "1.1.1.1" ];
      nat = {
        enable = true;
        internalInterfaces = [ "ve-+" ];
        externalInterface = hostNic;
      };
      firewall = {
        enable = true;
        interfaces.ve-reverseProxy.allowedTCPPorts = [
          8080 # Quartz
          8088 # Stirling PDF
          1337 # TMDB Addon
        ];
        allowedTCPPorts = [
          5201 # Probe point
        ];
        allowedUDPPorts = [
          5201 # Probe point
        ];
      };
    };

  systemd.tmpfiles.rules = [
    # NixOS containers
    "d /persist/containers/reverseProxy/caddy 0600 root root -"
    "d /persist/containers/ws-blog/app 0600 root root -"
    "d /persist/containers/ws-ots 0600 root root -"
    "d /persist/containers/ws-mastermovement 0600 root root -"
    "d /persist/containers/gitea 0600 root root -"
    "d /persist/containers/vaultwarden 0600 root root -"
    "d /persist/containers/nextcloud/app 0600 root root -"
    "d /persist/containers/nextcloud/db 0600 root root -"
    # Podman containers
    "d /persist/containers/ws-blog/quartz-vault 0600 root root -"
    "d /persist/containers/ws-blog/quartz-repo 0600 root root -"
    "d /persist/containers/stirling-pdf 0600 root root -"
    # Others
    # "d /var/lib/crowdsec 0755 crowdsec crowdsec"
  ];

  # Restart containers when systemd-tmpfiles config changes
  systemd.services.systemd-tmpfiles-resetup = {
    serviceConfig.ExecStartPost = let
      names = builtins.attrNames config.containers;
      units = map (n: "container@${n}.service") names;
    in
      lib.mkIf (names != []) [
        "+${config.systemd.package}/bin/systemctl restart ${lib.concatStringsSep " " units}"
      ];
  };

  containers =
    let
      common = {
        autoStart = true;
        ephemeral = true;
        enableTun = true;
        privateNetwork = true;
        extraFlags = [ "-U" ];
      };

      commonConfig = {
        nixpkgs.config.allowUnfree = true;
        system.stateVersion = config.system.stateVersion;
        networking.firewall.enable = false;

        environment.enableAllTerminfo = true;
        environment.systemPackages = with pkgs; [
          dig
          net-tools
        ];
      };

      commonWith = extra: common // extra;

      commonConfigWith =
        extraModule:
        { ... }@args:
        lib.mkMerge [
          commonConfig
          (if lib.isFunction extraModule then extraModule args else extraModule)
        ];
    in
    {
      reverseProxy = commonWith {
        hostAddress = addresses.reverseProxy.host;
        localAddress = addresses.reverseProxy.local;
        forwardPorts = [
          {
            containerPort = 80;
            hostPort = 80;
            protocol = "tcp";
          }
          {
            containerPort = 443;
            hostPort = 443;
            protocol = "tcp";
          }
          {
            containerPort = 51820;
            hostPort = 51820;
            protocol = "udp";
          }
        ];

        bindMounts."${config.sops.secrets.cloudy-private_wg.path}".isReadOnly = true;
        bindMounts."${config.sops.templates.env_caddy.path}".isReadOnly = true;
        bindMounts."/var/lib/caddy:idmap" = {
          hostPath = "/persist/containers/reverseProxy/caddy";
          isReadOnly = false;
        };

        config = commonConfigWith (
          { ... }:
          {
            networking = {
              wireguard.enable = true;
              wireguard.interfaces.wg0 = {
                ips = [ "10.69.69.1/24" ];
                listenPort = 51820;
                privateKeyFile = "${config.sops.secrets.cloudy-private_wg.path}";
                peers = [
                  {
                    publicKey = "urDeyjQQPARSSxK/J/WKH3m46Xg0zQjhCHwiWP2LEnM=";
                    allowedIPs = [
                      "10.69.69.2/32"
                      "10.0.3.0/24"
                    ];
                    persistentKeepalive = 20;
                  }
                ];
              };
              nameservers = [ "10.0.3.2" ];
            };

            services.caddy = {
              enable = true;
              package = pkgs.caddy.withPlugins {
                plugins = [
                  "github.com/caddy-dns/cloudflare@v0.2.1"
                  "github.com/caddyserver/replace-response@v0.0.0-20250618171559-80962887e4c6"
                ];
                hash = "sha256-zBhsiXgA4CAJgjgpHpLo27CFO5tF0x8YKbLvnUawmck=";
              };
              environmentFile = config.sops.templates.env_caddy.path;
              configFile =
                let
                  cf = ''
                    tls {
                      dns cloudflare {env.CF_API_KEY}
                      resolvers 1.1.1.1
                    }
                  '';
                  block-bots = ''
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
                  '';
                in
                pkgs.writeText "Caddyfile" ''
                  http://matheusplinta.com, https://matheusplinta.com {
                    ${cf}

                    redir https://www.matheusplinta.com{uri} permanent
                  }

                  *.matheusplinta.com {
                    ${cf}

                    @debug host debug.matheusplinta.com
                    handle @debug {
                      ${block-bots}
                      basic_auth {
                        mfplinta {env.HTTP_AUTH_PWD}
                      }
                      reverse_proxy localhost:2019 {
                        header_up Host {upstream_hostport}
                      }
                    }

                    @www host www.matheusplinta.com
                    handle @www {
                      redir /blog /blog/
                      handle_path /blog/* {
                        reverse_proxy ${addresses.reverseProxy.host}:8080
                      }
                      reverse_proxy ${addresses.ws-blog.local}:8000
                    }

                    @grafana host grafana.matheusplinta.com
                    handle @grafana {
                      ${block-bots}
                      reverse_proxy ${addresses.monitoring.local}:3000
                    }

                    @victoriametrics host victoriametrics.matheusplinta.com
                    handle @victoriametrics {
                      ${block-bots}
                      basic_auth {
                        mfplinta {env.HTTP_AUTH_PWD}
                      }
                      reverse_proxy ${addresses.monitoring.local}:8428
                    }

                    @gitea host gitea.matheusplinta.com
                    handle @gitea {
                      ${block-bots}
                      reverse_proxy ${addresses.gitea.local}:3000
                    }

                    @ha host ha.matheusplinta.com
                    handle @ha {
                      ${block-bots}
                      reverse_proxy https://ha.matheusplinta.com
                    }

                    @nextcloud host nextcloud.matheusplinta.com
                    handle @nextcloud {
                      ${block-bots}
                      reverse_proxy ${addresses.nextcloud.local}:8000
                    }

                    @nextcloud-ds host nextcloud-ds.matheusplinta.com
                    handle @nextcloud-ds {
                      ${block-bots}
                      reverse_proxy ${addresses.nextcloud.local}:8001 {
                        header_up Accept-Encoding identity
                      }

                      replace stream {
                        match {
                          header Content-Type text/javascript*
                        }
                        re `(function +\w+\(\w+\) *\{ *function +\w+\(\)) *\{ *(\w+)\.open\((\w+),(\w+),(\w+)\);` ` $1 {if( $4 && $4 .length>5&& $4 .substring(0,5)=="http:"){ $4 = $4 .replace("http:/","https:/");} $2 .open( $3 , $4 , $5 );`
                      }
                    }

                    @tmdb host tmdb-addon-stremio.matheusplinta.com
                    handle @tmdb {
                      ${block-bots}
                      reverse_proxy ${addresses.reverseProxy.host}:1337
                    }

                    @pdf host pdf.matheusplinta.com
                    handle @pdf {
                      ${block-bots}
                      reverse_proxy ${addresses.reverseProxy.host}:8088

                      # Remove "Upgrade to PRO"
                      replace stream {
                        match {
                          header Content-Type text/html*
                        }
                        `</body>` `<script>jQuery('#footer, .go-pro-badge, .lead.fs-4').remove();$('a.nav-link.go-pro-link').closest('li').remove();</script></body>`
                        `</head>` `<meta name="darkreader-lock"></head>`
                        `pixel.stirlingpdf.com` "{host}"
                      }
                    }

                    @vaultwarden host vaultwarden.matheusplinta.com
                    handle @vaultwarden {
                      ${block-bots}
                      reverse_proxy ${addresses.vaultwarden.local}:8222
                    }

                    handle {
                      abort
                    }
                  }

                  http://optimaltech.us, https://optimaltech.us {
                    ${cf}

                    redir https://www.optimaltech.us{uri} permanent 
                  }

                  *.optimaltech.us {
                    ${cf}

                    @www host www.optimaltech.us
                    handle @www {
                      reverse_proxy ${addresses.ws-ots.local}:8000
                    }

                    handle {
                      abort
                    }
                  }

                  http://mastermovement.us, https://mastermovement.us {
                    ${cf}

                    redir https://www.mastermovement.us{uri} permanent 
                  }

                  *.mastermovement.us {
                    ${cf}

                    @www host www.mastermovement.us
                    handle @www {
                      reverse_proxy ${addresses.ws-mastermovement.local}:8000
                    }

                    handle {
                      abort
                    }
                  }
                '';
            };
          }
        );
      };

      monitoring = commonWith {
        hostAddress = addresses.monitoring.host;
        localAddress = addresses.monitoring.local;

        bindMounts."${config.sops.secrets.cloudy-grafana_pwd.path}".isReadOnly = true;

        config = commonConfigWith (
          { ... }:
          {
            services.grafana = {
              enable = true;
              declarativePlugins = [ ];
              settings = {
                server = {
                  root_url = "https://grafana.matheusplinta.com/";
                  http_addr = "0.0.0.0";
                  http_port = 3000;
                };
                security = {
                  admin_password = "$__file{${config.sops.secrets.cloudy-grafana_pwd.path}}";
                };
                users.allow_sign_up = false;
                analytics.enabled = false;
                analytics.reporting_enabled = false;
                analytics.feedback_links_enabled = false;
                alerting.enabled = false;
                explore.enabled = false;
                profile.enabled = false;
                news.enabled = false;
                snapshots.enabled = false;
              };
              provision = {
                enable = true;
                dashboards.settings.providers = [
                  {
                    name = "my dashboards";
                    disableDeletion = true;
                    options = {
                      path = "/etc/grafana-dashboards";
                      foldersFromFilesStructure = true;
                    };
                  }
                ];
                datasources.settings.datasources = [
                  {
                    name = "VictoriaMetrics";
                    type = "prometheus";
                    url = "http://127.0.0.1:8428";
                    isDefault = true;
                    editable = false;
                  }
                ];
              };
            };

            environment.etc."grafana-dashboards/my_devices.json".source = ./my_devices.json;

            services.victoriametrics = {
              enable = true;
              listenAddress = ":8428";
            };
          }
        );
      };

      ws-blog = commonWith {
        hostAddress = addresses.ws-blog.host;
        localAddress = addresses.ws-blog.local;

        bindMounts."${config.sops.templates.env_blog.path}".isReadOnly = true;
        bindMounts."/app:idmap" = {
          hostPath = "/persist/containers/ws-blog/app";
          isReadOnly = false;
        };

        config = websiteConfig {
          appName = "matheusplintacom";
          envFile = config.sops.templates.env_blog.path;
        };
      };

      ws-ots = commonWith {
        hostAddress = addresses.ws-ots.host;
        localAddress = addresses.ws-ots.local;

        bindMounts."${config.sops.templates.env_ots.path}".isReadOnly = true;
        bindMounts."/app:idmap" = {
          hostPath = "/persist/containers/ws-ots";
          isReadOnly = false;
        };

        config = websiteConfig {
          appName = "otswebsite";
          envFile = config.sops.templates.env_ots.path;
        };
      };

      ws-mastermovement = commonWith {
        hostAddress = addresses.ws-mastermovement.host;
        localAddress = addresses.ws-mastermovement.local;

        bindMounts."${config.sops.templates.env_mastermovement.path}".isReadOnly = true;
        bindMounts."/app:idmap" = {
          hostPath = "/persist/containers/ws-mastermovement";
          isReadOnly = false;
        };

        config = websiteConfig {
          appName = "mastermovement";
          envFile = config.sops.templates.env_mastermovement.path;
        };
      };

      gitea = commonWith {
        hostAddress = addresses.gitea.host;
        localAddress = addresses.gitea.local;

        bindMounts."/var/lib/gitea:idmap" = {
          hostPath = "/persist/containers/gitea";
          isReadOnly = false;
        };

        config = commonConfigWith (
          { ... }:
          {
            systemd.tmpfiles.rules = [
              "d /var/lib/gitea 0755 gitea gitea -"
            ];

            services.gitea = {
              enable = true;
              stateDir = "/var/lib/gitea";
              settings = {
                actions.ENABLED = true;
                other.SHOW_FOOTER_VERSION = false;
                session.COOKIE_SECURE = true;
                server.ROOT_URL = "https://gitea.matheusplinta.com/";
                "service.explore".DISABLE_USERS_PAGE = true;
                "service.explore".DISABLE_ORGANIZATIONS_PAGE = true;
                service.DISABLE_REGISTRATION = true;
                repository.DISABLE_STARS = true;
              };
            };
          }
        );
      };

      vaultwarden = commonWith {
        hostAddress = addresses.vaultwarden.host;
        localAddress = addresses.vaultwarden.local;

        bindMounts."/var/lib/vaultwarden:idmap" = {
          hostPath = "/persist/containers/vaultwarden";
          isReadOnly = false;
        };

        config = commonConfigWith (
          { ... }:
          {
            systemd.tmpfiles.rules = [
              "d /data 0755 vaultwarden vaultwarden -"
            ];

            services.vaultwarden = {
              enable = true;
              config.ROCKET_ADDRESS = "0.0.0.0";
              config.ROCKET_PORT = 8222;
              config.DATA_FOLDER = "/var/lib/vaultwarden";
              config.DOMAIN = "https://vaultwarden.matheusplinta.com";
              config.SIGNUPS_ALLOWED = false;
            };
          }
        );
      };

      nextcloud = commonWith {
        hostAddress = addresses.nextcloud.host;
        localAddress = addresses.nextcloud.local;

        bindMounts."${config.sops.secrets.cloudy-nextcloud_admin.path}".isReadOnly = true;
        bindMounts."${config.sops.secrets.cloudy-nextcloud_onlyoffice_jwt.path}".isReadOnly = true;
        bindMounts."${config.sops.templates.nextcloud_nonce.path}".isReadOnly = true;

        bindMounts."/var/lib/nextcloud:idmap" = {
          hostPath = "/persist/containers/nextcloud/app";
          isReadOnly = false;
        };

        bindMounts."/var/lib/postgresql:idmap" = {
          hostPath = "/persist/containers/nextcloud/db";
          isReadOnly = false;
        };

        config = commonConfigWith (
          { config, ... }:
          {
            environment.systemPackages = with pkgs; [
              config.services.nextcloud.occ
              cron
              ghostscript
              exiftool
            ];

            services.onlyoffice = {
              enable = true;
              hostname = "onlyoffice";
              port = 10000;
              jwtSecretFile = "${hostConfig.sops.secrets.cloudy-nextcloud_onlyoffice_jwt.path}";
              securityNonceFile = "${hostConfig.sops.templates.nextcloud_nonce.path}";
            };
            services.nginx.virtualHosts."${config.services.onlyoffice.hostname}".listen = [
              {
                addr = "0.0.0.0";
                port = 8001;
              }
            ];

            services.nextcloud = {
              enable = true;
              package = pkgs.nextcloud32;
              extraAppsEnable = true;
              extraApps = {
                inherit (pkgs.nextcloud32.packages.apps)
                  bookmarks
                  end_to_end_encryption
                  memories
                  previewgenerator
                  onlyoffice
                  ;
              };
              hostName = "nextcloud";
              https = true;
              configureRedis = true;
              maxUploadSize = "20G";
              database.createLocally = true;
              phpOptions = {
                "opcache.interned_strings_buffer" = "32";
              };
              caching = {
                redis = true;
                memcached = true;
              };
              config = {
                dbtype = "pgsql";
                adminuser = "admin";
                adminpassFile = "${hostConfig.sops.secrets.cloudy-nextcloud_admin.path}";
              };
              settings.maintenance_window_start = 9; # 2 AM MST
              settings.default_phone_region = "US";
              settings.trusted_domains = [
                "nextcloud.matheusplinta.com"
              ];
              settings.trusted_proxies = [
                "127.0.0.1"
                addresses.reverseProxy.local
              ];
              settings.filelocking.enabled = true;
              settings.log_type = "file";
              settings."overwriteprotocol" = "https"; # Fix redirect after login
              settings."preview_ffmpeg_path" = "${pkgs.ffmpeg}/bin/ffmpeg";
              settings.enabledPreviewProviders = [
                "OC\\Preview\\BMP"
                "OC\\Preview\\GIF"
                "OC\\Preview\\JPEG"
                "OC\\Preview\\Krita"
                "OC\\Preview\\MarkDown"
                "OC\\Preview\\MP3"
                "OC\\Preview\\OpenDocument"
                "OC\\Preview\\PNG"
                "OC\\Preview\\TXT"
                "OC\\Preview\\XBitmap"
                "OC\\Preview\\Movie"
                "OC\\Preview\\MSOffice2003"
                "OC\\Preview\\MSOffice2007"
                "OC\\Preview\\MSOfficeDoc"
                "OC\\Preview\\PDF"
                "OC\\Preview\\Photoshop"
                "OC\\Preview\\SVG"
                "OC\\Preview\\TIFF"
                "OC\\Preview\\HEIC"
              ];
            };
            services.nginx.virtualHosts."${config.services.nextcloud.hostName}".listen = [
              {
                addr = "0.0.0.0";
                port = 8000;
              }
            ];
          }
        );
      };
    };

  virtualisation.podman.enable = true;
  virtualisation.podman.defaultNetwork.settings = {
    dns_enabled = true;
  };
  users.groups.containers = { };
  users.users.containers = {
    home = "/persist/podman";
    isNormalUser = true;
    group = "containers";

    subUidRanges = [
      {
        startUid = 100000;
        count = 65536;
      }
    ];
    subGidRanges = [
      {
        startGid = 100000;
        count = 65536;
      }
    ];
  };

  virtualisation.quadlet = {
    enable = true;
    autoUpdate.enable = true;
    containers = {
      # --- Quartz ---
      quartz.containerConfig = {
        image = "docker.io/mfplinta016/dockerized-quartz:latest";
        publishPorts = [ "8080:80" ];
        userns = "auto";
        volumes = [
          "/persist/containers/ws-blog/quartz-vault:/vault:ro,U"
          "/persist/containers/ws-blog/quartz-repo:/usr/src/app/quartz:U"
        ];
        environments = {
          GIT_BRANCH = "jackyzha0/v4";
          AUTO_REBUILD = "true";
        };
      };

      # --- TMDB Addon ---
      tmdb-addon.containerConfig = {
        autoUpdate = "registry";
        image = "docker.io/viren070/tmdb-addon:latest";
        publishPorts = [ "1337:1337" ];
        userns = "auto";
        environmentFiles = [ config.sops.templates.env_tmdb.path ];
      };

      # --- Stirling PDF ---
      stirling-pdf.containerConfig = {
        autoUpdate = "registry";
        image = "docker.stirlingpdf.com/stirlingtools/stirling-pdf:latest";
        publishPorts = [ "8088:8080" ];
        userns = "auto";
        volumes = [
          "/persist/containers/stirling-pdf/trainingData:/usr/share/tessdata:U"
          "/persist/containers/stirling-pdf/extraConfigs:/configs:U"
          "/persist/containers/stirling-pdf/customFiles:/customFiles:U"
          "/persist/containers/stirling-pdf/logs:/logs:U"
          "/persist/containers/stirling-pdf/pipeline:/pipeline:U"
        ];
        environments = {
          DISABLE_ADDITIONAL_FEATURES = "false";
          LANGS = "en_US";
        };
      };
    };
  };

  services.crowdsec = {
    enable = true;
    settings = {
      general.api.server.enable = true;
      general.api.server.listen_uri = "127.0.0.1:30000";
      general.api.server.online_client.credentials_path = "/var/lib/crowdsec/online_api_credentials.yaml";
      console.tokenFile = config.sops.secrets.cloudy-crowdsec_token.path;
      console.configuration = {
        share_context = true;
        share_custom = true;
        share_manual_decisions = true;
        share_tainted = false;
      };
      acquisitions = [
        {
          source = "journalctl";
          journalctl_filter = [ "_SYSTEMD_UNIT=sshd.service" ];
          labels = {
            type = "syslog";
          };
        }
      ];
    };
    hub.collections = [
      "crowdsecurity/linux"
      "crowdsecurity/sshd"
    ];
  };

  services.crowdsec-firewall-bouncer = {
    enable = true;
    registerBouncer.enable = true;
  };

  services.endlessh = {
    enable = true;
    port = 22;
    openFirewall = true;
  };

  services.openssh.ports = [ 22000 ];

  myCfg.vmagentEnable = true;
  myCfg.vmagentRemoteWriteUrl = "http://${addresses.monitoring.local}:8428/api/v1/write";
}
