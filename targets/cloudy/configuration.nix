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
    gitea = {
      host = "192.168.104.10";
      local = "192.168.104.11";
    };
    ws-blog = {
      host = "192.168.102.10";
      local = "192.168.102.11";
    };
    ws-ots = {
      host = "192.168.103.10";
      local = "192.168.103.11";
    };
    ws-mastermovement = {
      host = "192.168.105.10";
      local = "192.168.105.11";
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
            runtimeInputs = [ git ];
            text = ''
              set -e
              set -x

              if [ -f manage.py ] && [ -d .git ]; then
                  git config --global --add safe.directory '*'
                  git pull
                  ${lib.getExe caddy-django-env} manage.py collectstatic --noinput
                  chown -R django:django media staticfiles
                  systemctl restart django-gunicorn.service
              else
                  echo "manage.py or .git not found in current dir"
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

  sops.defaultSopsFile = ./../secrets.yaml;
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
  sops.secrets.cloudy-private_wg = {
    mode = "0444";
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
        allowedTCPPorts = [
          5201 # Probe point
        ];
        allowedUDPPorts = [
          5201 # Probe point
        ];
      };
    };

  systemd.tmpfiles.rules = [
    "d /persist/containers/reverseProxy/caddy 0600 root root -"
    "d /persist/containers/ws-blog/app 0600 root root -"
    "d /persist/containers/ws-blog/quartz-vault 0600 root root -"
    "d /persist/containers/ws-blog/quartz-repo 0600 root root -"
    "d /persist/containers/ws-ots 0600 root root -"
    "d /persist/containers/ws-mastermovement 0600 root root -"
    "d /persist/containers/gitea 0600 root root -"
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

            services.caddy = {
              enable = true;
              package = pkgs.caddy.withPlugins {
                plugins = [
                  "github.com/caddy-dns/cloudflare@v0.2.1"
                ];
                hash = "sha256-S1JN7brvH2KIu7DaDOH1zij3j8hWLLc0HdnUc+L89uU=";
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
                in
                pkgs.writeText "Caddyfile" ''
                matheusplinta.com {
                  ${cf}

                  reverse_proxy ${addresses.ws-blog.local}:8000
                }

                *.matheusplinta.com {
                  ${cf}

                  @debug host debug.matheusplinta.com
                  handle @debug {
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

                  @blog host blog.matheusplinta.com
                  handle @blog {
                    reverse_proxy ${addresses.reverseProxy.host}:8080
                  }

                  @grafana host grafana.matheusplinta.com
                  handle @grafana {
                    reverse_proxy ${addresses.monitoring.local}:3000
                  }

                  @victoriametrics host victoriametrics.matheusplinta.com
                  handle @victoriametrics {
                    basic_auth {
                      mfplinta {env.HTTP_AUTH_PWD}
                    }
                    reverse_proxy ${addresses.monitoring.local}:8428
                  }

                  @gitea host gitea.matheusplinta.com
                  handle @gitea {
                    reverse_proxy ${addresses.gitea.local}:3000
                  }

                  @ha host ha.matheusplinta.com
                  handle @ha {
                    reverse_proxy https://ha.matheusplinta.com
                  }

                  @vaultwarden host vaultwarden.matheusplinta.com
                  handle @vaultwarden {
                    reverse_proxy https://vaultwarden.matheusplinta.com
                  }

                  @nextcloud host nextcloud.matheusplinta.com
                  handle @nextcloud {
                    reverse_proxy https://nextcloud.matheusplinta.com
                  }

                  handle {
                    abort
                  }
                }

                optimaltech.us {
                  ${cf}

                  reverse_proxy ${addresses.ws-ots.local}:8000
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

                mastermovement.us {
                  ${cf}

                  reverse_proxy ${addresses.ws-mastermovement.local}:8000
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
    };

  virtualisation.docker.enable = true;
  virtualisation.oci-containers.backend = "docker";
  virtualisation.oci-containers.containers.quartz = {
    autoStart = true;
    image = "docker.io/ilkersigirci/dockerized-quartz:latest";
    environment = {
      GIT_BRANCH = "jackyzha0/fix-docker";
      AUTO_REBUILD = "true";
    };
    volumes = [
      "/persist/containers/ws-blog/quartz-vault:/vault:ro"
      "/persist/containers/ws-blog/quartz-repo:/usr/src/app/quartz"
    ];
    ports = [ "8080:80" ];
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
