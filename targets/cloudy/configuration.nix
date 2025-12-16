{
  pkgs,
  lib,
  config,
  sysImport,
  ...
}:

let
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
    {appName, envFile, extra ? {}}:
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
            runtimeInputs = [ git caddy-django-env ];
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
          after = [ "network.target" "systemd-tmpfiles-setup.service" ];
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
  sops.secrets.cloudy-nextcloud_admin = { };
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

  networking =
    let
      hostNic = "eth0";
    in
    {
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
  ];

  containers =
    let
      common = {
        autoStart = true;
        ephemeral = true;
        enableTun = true;
        privateNetwork = true;
        extraFlags = [ "-U" ];
      };
    in
    {
      reverseProxy = common // {
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

        config =
          { ... }:
          {
            system.stateVersion = config.system.stateVersion;
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
              firewall.enable = false;
              nameservers = [ "10.0.3.2" ];
            };

            environment.systemPackages = with pkgs; [ dig ];

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
                      "</body>" "<script>jQuery('#footer, .go-pro-badge, .lead.fs-4').remove();$('a.nav-link.go-pro-link').closest('li').remove();</script></body>"
                      "</head>" "<meta name=\"darkreader-lock\"></head>"
                      "pixel.stirlingpdf.com" "{host}"
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
          };
      };

      monitoring = common // {
        hostAddress = addresses.monitoring.host;
        localAddress = addresses.monitoring.local;

        bindMounts."${config.sops.secrets.cloudy-grafana_pwd.path}".isReadOnly = true;

        config =
          { ... }:
          {
            system.stateVersion = config.system.stateVersion;
            networking.firewall.enable = false;

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
          };
      };

      ws-blog = common // {
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

      ws-ots = common // {
        hostAddress = addresses.ws-ots.host;
        localAddress = addresses.ws-ots.local;

        bindMounts."${config.sops.templates.env_ots.path}".isReadOnly = true;
        bindMounts."/app:idmap" = {
          hostPath = "/persist/containers/ws-ots";
          isReadOnly = false;
        };

        config = websiteConfig { appName = "otswebsite"; envFile = config.sops.templates.env_ots.path; };
      };

      ws-mastermovement = common // {
        hostAddress = addresses.ws-mastermovement.host;
        localAddress = addresses.ws-mastermovement.local;

        bindMounts."${config.sops.templates.env_mastermovement.path}".isReadOnly = true;
        bindMounts."/app:idmap" = {
          hostPath = "/persist/containers/ws-mastermovement";
          isReadOnly = false;
        };

        config = websiteConfig { appName = "mastermovement"; envFile = config.sops.templates.env_mastermovement.path; };
      };

      gitea = common // {
        hostAddress = addresses.gitea.host;
        localAddress = addresses.gitea.local;

        bindMounts."/var/lib/gitea:idmap" = {
          hostPath = "/persist/containers/gitea";
          isReadOnly = false;
        };

        config =
          { ... }:
          {
            system.stateVersion = config.system.stateVersion;
            networking.firewall.enable = false;

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
          };
      };

      vaultwarden = common // {
        hostAddress = addresses.vaultwarden.host;
        localAddress = addresses.vaultwarden.local;

        bindMounts."/var/lib/vaultwarden:idmap" = {
          hostPath = "/persist/containers/vaultwarden";
          isReadOnly = false;
        };

        config =
          { ... }:
          {
            system.stateVersion = config.system.stateVersion;
            networking.firewall.enable = false;

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
          };
      };

      nextcloud = common // {
        hostAddress = addresses.nextcloud.host;
        localAddress = addresses.nextcloud.local;

        bindMounts."${config.sops.secrets.cloudy-nextcloud_admin.path}".isReadOnly = true;

        bindMounts."/var/lib/nextcloud:idmap" = {
          hostPath = "/persist/containers/nextcloud/app";
          isReadOnly = false;
        };

        bindMounts."/var/lib/postgresql:idmap" = {
          hostPath = "/persist/containers/nextcloud/db";
          isReadOnly = false;
        };

        config =
          { ... }:
          let
            hostName = "nextcloud";
          in
          {
            system.stateVersion = config.system.stateVersion;
            networking.firewall.enable = false;

            services.nextcloud = {
              enable = true;
              package = pkgs.nextcloud32;
              extraAppsEnable = true;
              extraApps = {
                inherit (pkgs.nextcloud32.packages.apps) calendar bookmarks;
              };
              hostName = hostName;
              https = true;
              configureRedis = true;
              phpOptions = {
                "opcache.interned_strings_buffer" = "16";
              };
              caching = {
                redis = true;
                memcached = true;
              };
              maxUploadSize = "20G";
              database.createLocally = true;
              settings.maintenance_window_start = 9; # 2 AM MST
              settings.default_phone_region = "US";
              settings.trusted_domains = [
                "nextcloud.matheusplinta.com"
              ];
              settings.trusted_proxies = [
                "127.0.0.1"
              ];
              settings.filelocking.enabled = true;
              settings.log_type = "file";
              config = {
                dbtype = "pgsql";
                adminuser = "admin";
                adminpassFile = "${config.sops.secrets.cloudy-nextcloud_admin.path}";
              };
              settings."overwriteprotocol" = "https"; # Fix redirect after login
            };
            services.nginx.virtualHosts."${hostName}".listen = [
              {
                addr = "127.0.0.1";
                port = 8000;
              }
            ];
          };
      };
    };

  virtualisation.podman.enable = true;
  virtualisation.podman.defaultNetwork.settings = { dns_enabled = true; };
  virtualisation.oci-containers.backend = "podman";
  users.groups.containers = {};
  users.users.containers = {
    home = "/persist/podman";
    isNormalUser = true;
    group = "containers";

    subUidRanges = [ { startUid = 100000; count = 65536; } ];
    subGidRanges = [ { startGid = 100000; count = 65536; } ];
  };

  virtualisation.quadlet = {
    enable = true;
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
        image = "docker.io/viren070/tmdb-addon:latest";
        publishPorts = [ "1337:1337" ];
        userns = "auto";
        environmentFiles = [ config.sops.templates.env_tmdb.path ];
      };

      # --- Stirling PDF ---
      stirling-pdf.containerConfig = {
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

  services.fail2ban.enable = true;

  services.endlessh = {
    enable = true;
    port = 22;
    openFirewall = true;
  };

  services.openssh.ports = [ 22000 ];

  myCfg.vmagentEnable = true;
  myCfg.vmagentRemoteWriteUrl = "http://${addresses.monitoring.local}:8428/api/v1/write";
}
