{
  pkgs,
  lib,
  config,
  inputs,
  sysImport,
  private,
  ...
}:

let
  hostNic = "eth0";
  hostAddress = "10.0.0.104";
  bridgeAddress = "192.168.100.1";
  hostConfig = config;
  configuredContainerNames =
    (builtins.attrNames config.containers)
    ++ (builtins.attrNames config.virtualisation.quadlet.containers);
  containerNames = [
    "audiobookshelf"
    "gitea"
    "monitoring"
    "nextcloud"
    "reverseProxy"
    "vaultwarden"
    "ws-blog"
    "ws-mastermovement"
    "ws-ots"
    "contractual-app"
    "coturn"
    "quartz"
    "stirling-pdf"
    "tmdb-addon"
  ];
  addresses = lib.listToAttrs (
    lib.imap0 (i: name: {
      inherit name;
      value = rec {
        local = "192.168.100.${toString (100 + i)}";
        localWithSubnet = "${local}/24";
      };
    }) containerNames
  );
in
{
  assertions = [
    {
      assertion =
        lib.sort builtins.lessThan configuredContainerNames == lib.sort builtins.lessThan containerNames;
      message = "Cloudy container names changed; update containerNames explicitly to allocate a stable IP";
    }
  ];

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

  sops.defaultSopsFile = private.secretsFile;
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
  sops.secrets.cloudy-coturn_pwd = { };
  sops.templates.env_tmdb = {
    mode = "0444";
    content = ''
      TMDB_API=${config.sops.placeholder.cloudy-tmdb_api}
      FANART_API=${config.sops.placeholder.cloudy-fanart_api}
      MONGODB_URI=${config.sops.placeholder.cloudy-tmdb_mongodb_uri}
      HOST_NAME=https://tmdb-addon-stremio.plinta.dev
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
    mode = "0400";
    content = ''
      SECRET_KEY=${config.sops.placeholder.cloudy-blog_secretkey}
    '';
  };
  sops.templates.env_ots = {
    mode = "0400";
    content = ''
      SECRET_KEY=${config.sops.placeholder.cloudy-ots_secretkey}
      TURNSTILE_SITEKEY=${config.sops.placeholder.cloudy-ots_turnstile_sitekey}
      TURNSTILE_SECRET=${config.sops.placeholder.cloudy-ots_turnstile_secret}
    '';
  };
  sops.templates.env_mastermovement = {
    mode = "0400";
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
  sops.templates.env_coturn = {
    mode = "0444";
    content = ''
      user=ha:${config.sops.placeholder.cloudy-coturn_pwd}
    '';
  };

  networking = {
    ### Basic network config ###
    useDHCP = false;
    interfaces = {
      "${hostNic}".ipv4.addresses = [
        {
          address = hostAddress;
          prefixLength = 24;
        }
      ];
      "br0".ipv4.addresses = [
        {
          address = bridgeAddress;
          prefixLength = 24;
        }
      ];
    };
    defaultGateway = {
      address = "10.0.0.1";
      interface = "eth0";
    };
    nameservers = [ "1.1.1.1" ];
    nftables.enable = true;
    ### Container bridge cfg ###
    bridges."br0".interfaces = [ ];
    nat = {
      enable = true;
      internalInterfaces = [ "br0" ];
      externalInterface = hostNic;
      forwardPorts = [
        {
          destination = "${addresses.reverseProxy.local}:80";
          proto = "tcp";
          sourcePort = 80;
        }
        {
          destination = "${addresses.reverseProxy.local}:443";
          proto = "tcp";
          sourcePort = 443;
        }
        {
          destination = "${addresses.reverseProxy.local}:51820";
          proto = "udp";
          sourcePort = 51820;
        }
        {
          destination = "${addresses.coturn.local}:3478";
          proto = "tcp";
          sourcePort = 3478;
        }
        {
          destination = "${addresses.coturn.local}:3478";
          proto = "udp";
          sourcePort = 3478;
        }
        {
          destination = "${addresses.coturn.local}:10000-20000";
          proto = "udp";
          sourcePort = "10000:20000";
        }
      ];
    };
    firewall.enable = true;
    firewall.trustedInterfaces = [ "br0" ];
  };

  systemd.tmpfiles.rules = [
    # NixOS containers
    "d /persist/containers/reverseProxy/caddy 0600 root root -"
    "d /persist/containers/reverseProxy/log 0600 root root -"
    "d /persist/containers/ws-mastermovement 0700 root root -"
    "d /persist/containers/gitea 0600 root root -"
    "d /persist/containers/vaultwarden 0600 root root -"
    "d /persist/containers/nextcloud/app 0600 root root -"
    "d /persist/containers/nextcloud/db 0600 root root -"
    "d /persist/containers/audiobookshelf/config 0600 root root -"
    "d /persist/containers/audiobookshelf/audiobooks 0600 root root -"
    # "d /persist/containers/lidarr 0600 root root -"
    # Podman containers
    "d /persist/containers/ws-blog/app 0700 root root -"
    "d /persist/containers/ws-ots 0700 root root -"
    "d /persist/containers/ws-blog/quartz-vault 0600 root root -"
    "d /persist/containers/ws-blog/quartz-repo 0600 root root -"
    "d /persist/containers/stirling-pdf 0600 root root -"
    "d /persist/containers/contractual/app 0600 root root -"
    # Shared media dirs
    "d /persist/media/audiobooks"
    "d /persist/media/music"
  ];

  # Restart containers when systemd-tmpfiles config changes
  systemd.services.systemd-tmpfiles-resetup = {
    serviceConfig.ExecStartPost =
      let
        names = builtins.attrNames config.containers;
        units = map (n: "container@${n}.service") names;
      in
      lib.mkIf (names != [ ]) [
        "+${config.systemd.package}/bin/systemctl restart ${lib.concatStringsSep " " units}"
      ];
  };

  cfg.virtualisation.quadlet.enable = true;
  containers =
    let
      common = {
        autoStart = true;
        ephemeral = true;
        enableTun = true;
        privateNetwork = true;
        extraFlags = [ "-U" ];
        hostBridge = "br0";
      };

      commonConfig = {
        nixpkgs.pkgs = pkgs;
        system.stateVersion = config.system.stateVersion;
        networking.firewall.enable = false;
        networking.defaultGateway = bridgeAddress;

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
        let
          extra = if lib.isFunction extraModule then extraModule args else extraModule;
        in
        {
          imports = (extra.imports or [ ]) ++ [
            (sysImport ../../modules/services/django-website.nix)
            (sysImport ../../modules/services/caddy.nix)
            (sysImport ../../modules/services/nextcloud.nix)
          ];

          config = lib.mkMerge [
            commonConfig
            (removeAttrs extra [ "imports" ])
          ];
        };

      djangoWebsite =
        {
          name,
          source,
          appName,
          envFile,
          hostStatePath,
          extraPythonPackages ? (_: [ ]),
          validateMigrations ? true,
        }:
        commonWith {
          localAddress = addresses.${name}.localWithSubnet;

          bindMounts."${envFile}:idmap" = {
            hostPath = envFile;
            isReadOnly = true;
          };
          bindMounts."/var/lib/django-website:idmap" = {
            hostPath = hostStatePath;
            isReadOnly = false;
          };

          config = commonConfigWith {
            cfg.services.django-website = {
              enable = true;
              inherit
                appName
                envFile
                extraPythonPackages
                source
                validateMigrations
                ;
            };
          };
        };
    in
    {
      reverseProxy = commonWith {
        localAddress = addresses.reverseProxy.localWithSubnet;

        bindMounts."${config.sops.secrets.cloudy-private_wg.path}".isReadOnly = true;
        bindMounts."${config.sops.templates.env_caddy.path}".isReadOnly = true;
        bindMounts."/var/lib/caddy:idmap" = {
          hostPath = "/persist/containers/reverseProxy/caddy";
          isReadOnly = false;
        };
        bindMounts."/var/log/caddy:idmap" = {
          hostPath = "/persist/containers/reverseProxy/log";
          isReadOnly = false;
        };

        config = commonConfigWith (
          { ... }:
          {
            users.groups.caddy = { };
            users.users.caddy = {
              group = "caddy";
            };
            systemd.tmpfiles.rules = [
              "d /var/log/caddy 0644 caddy caddy -"
            ];

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

            cfg.services.caddy = {
              enable = true;
              environmentFile = config.sops.templates.env_caddy.path;
              metrics.enable = true;
              metrics.loki.enable = true;
              metrics.loki.endpoint = "http://${addresses.monitoring.local}:9428/insert/loki/api/v1/push";
              config = /* caddy */ ''
                (cf) {
                  tls {
                    dns cloudflare {env.CF_API_KEY}
                    resolvers 1.1.1.1
                  }
                }

                (rp) {
                  reverse_proxy {args[0]} {
                  fail_duration 30s
                  unhealthy_status 5xx
                  unhealthy_latency 10s
                  }
                }

                http://plinta.dev, https://plinta.dev {
                  import cf
                  redir https://www.plinta.dev{uri} permanent
                }

                *.plinta.dev {
                  import cf
                  log
                  @www host www.plinta.dev
                  handle @www {
                    redir /blog /blog/
                    handle_path /blog/* {
                      import rp ${addresses.quartz.local}:80
                    }
                    reverse_proxy ${addresses.ws-blog.local}:8000 {
                      import tunneled
                    }
                  }

                  @grafana host grafana.plinta.dev
                  handle @grafana {
                    import bot_block
                    import rp ${addresses.monitoring.local}:3000
                  }

                  @victoriametrics host victoriametrics.plinta.dev
                  handle @victoriametrics {
                    import bot_block
                    basic_auth {
                      mfplinta {env.HTTP_AUTH_PWD}
                    }
                    import rp ${addresses.monitoring.local}:8428
                  }

                  @gitea host gitea.plinta.dev
                  handle @gitea {
                    import bot_block
                    import rp ${addresses.gitea.local}:3000
                  }

                  @ha host ha.plinta.dev
                  handle @ha {
                    import bot_block
                    reverse_proxy https://ha.plinta.dev {
                    #health_uri /
                    #health_timeout 10s
                    }
                  }

                  @nextcloud host nextcloud.plinta.dev
                  handle @nextcloud {
                    import bot_block
                    import rp ${addresses.nextcloud.local}:8000
                  }

                  @nextcloud-ds host nextcloud-ds.plinta.dev
                  handle @nextcloud-ds {
                    import bot_block
                    import rp ${addresses.nextcloud.local}:8001 {
                      header_up Accept-Encoding identity
                    }

                    replace stream {
                      match {
                        header Content-Type text/javascript*
                      }
                      re `(function +\w+\(\w+\) *\{ *function +\w+\(\)) *\{ *(\w+)\.open\((\w+),(\w+),(\w+)\);` ` $1 {if( $4 && $4 .length>5&& $4 .substring(0,5)=="http:"){ $4 = $4 .replace("http:/","https:/");} $2 .open( $3 , $4 , $5 );`
                    }
                  }

                  @tmdb host tmdb-addon-stremio.plinta.dev
                  handle @tmdb {
                    import bot_block
                    import rp ${addresses.tmdb-addon.local}:1337
                  }

                  @pdf host pdf.plinta.dev
                  handle @pdf {
                    import bot_block
                    import rp ${addresses.stirling-pdf.local}:8080

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

                  @vaultwarden host vaultwarden.plinta.dev
                  handle @vaultwarden {
                    import bot_block
                    import rp ${addresses.vaultwarden.local}:8222
                  }

                  @audiobookshelf host audiobooks.plinta.dev
                  handle @audiobookshelf {
                    import bot_block
                    import rp ${addresses.audiobookshelf.local}:8000
                  }

                  handle {
                    abort
                  }
                }

                http://optimaltech.us, https://optimaltech.us {
                  import cf
                  redir https://www.optimaltech.us{uri} permanent
                }

                *.optimaltech.us {
                  import cf
                  log
                  @www host www.optimaltech.us
                  handle @www {
                    reverse_proxy ${addresses.ws-ots.local}:8000 {
                      import tunneled
                    }
                  }

                  handle {
                    abort
                  }
                }

                http://mastermovement.us, https://mastermovement.us {
                  import cf
                  redir https://www.mastermovement.us{uri} permanent
                }

                *.mastermovement.us {
                  import cf
                  log
                  @www host www.mastermovement.us
                  handle @www {
                    reverse_proxy ${addresses.ws-mastermovement.local}:8000 {
                      import tunneled
                    }
                  }

                  @contractual host app.mastermovement.us
                  handle @contractual {
                    import bot_block
                    import rp ${addresses.contractual-app.local}:80
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
        localAddress = addresses.monitoring.localWithSubnet;

        bindMounts."${config.sops.secrets.cloudy-grafana_pwd.path}".isReadOnly = true;

        config = commonConfigWith (
          { ... }:
          {
            services.grafana = {
              enable = true;
              declarativePlugins = [
                pkgs.grafanaPlugins.victoriametrics-logs-datasource
              ];
              settings = {
                server = {
                  root_url = "https://grafana.plinta.dev/";
                  http_addr = "0.0.0.0";
                  http_port = 3000;
                };
                security = {
                  admin_password = "$__file{${config.sops.secrets.cloudy-grafana_pwd.path}}";
                  secret_key = "SW2YcwTIb9zpOOhoPsMm";
                };
                users.allow_sign_up = false;
                users.home_page = "/d/${(builtins.fromJSON (builtins.readFile ./my_devices.json)).uid}";
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
                  {
                    name = "VictoriaLogs";
                    type = "victoriametrics-logs-datasource";
                    access = "direct";
                    url = "http://127.0.0.1:9428";
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

            services.victorialogs = {
              enable = true;
              listenAddress = ":9428";
            };
          }
        );
      };

      ws-mastermovement = djangoWebsite {
        name = "ws-mastermovement";
        source = inputs.mastermovement;
        appName = "mastermovement";
        envFile = config.sops.templates.env_mastermovement.path;
        hostStatePath = "/persist/containers/ws-mastermovement";
        extraPythonPackages = pythonPackages: [ (pkgs.django-turnstile pythonPackages) ];
      };

      gitea = commonWith {
        localAddress = addresses.gitea.localWithSubnet;

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
                server.ROOT_URL = "https://gitea.plinta.dev/";
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
        localAddress = addresses.vaultwarden.localWithSubnet;

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
              config.DOMAIN = "https://vaultwarden.plinta.dev";
              config.SIGNUPS_ALLOWED = false;
            };
          }
        );
      };

      nextcloud = commonWith {
        localAddress = addresses.nextcloud.localWithSubnet;

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
          { ... }:
          {
            cfg.services.nextcloud = {
              enable = true;
              adminPasswordFile = hostConfig.sops.secrets.cloudy-nextcloud_admin.path;
              trustedDomains = [ "nextcloud.plinta.dev" ];
              trustedProxies = [ addresses.reverseProxy.local ];
              onlyoffice = {
                enable = true;
                jwtSecretFile = hostConfig.sops.secrets.cloudy-nextcloud_onlyoffice_jwt.path;
                securityNonceFile = hostConfig.sops.templates.nextcloud_nonce.path;
              };
            };
          }
        );
      };

      audiobookshelf = commonWith {
        localAddress = addresses.audiobookshelf.localWithSubnet;

        bindMounts."/var/lib/audiobookshelf:idmap" = {
          hostPath = "/persist/containers/audiobookshelf/config";
          isReadOnly = false;
        };

        bindMounts."/audiobooks:idmap" = {
          hostPath = "/persist/media/audiobooks";
          isReadOnly = false;
        };

        config = commonConfigWith (
          { ... }:
          {
            systemd.tmpfiles.rules = [
              "d /audiobooks 0755 audiobookshelf audiobookshelf -"
            ];
            services.audiobookshelf = {
              enable = true;
              host = "0.0.0.0";
            };
          }
        );
      };
    };

  virtualisation.quadlet =
    let
      inherit (config.virtualisation.quadlet) networks;
    in
    {
      autoEscape = true;
      networks = {
        net_br0.networkConfig = {
          driver = "bridge";
          gateways = [ bridgeAddress ];
          subnets = [ "192.168.100.0/24" ];
          options.mode = "unmanaged";
          podmanArgs = [ "--interface-name=br0" ];
        };
      };
      containers = {
        ws-blog = {
          serviceConfig.Restart = "on-failure";
          containerConfig = {
            autoUpdate = "registry";
            image = "ghcr.io/mfplinta/portfolio:latest";
            userns = "auto";
            networks = [ "${networks.net_br0.ref}:ip=${addresses.ws-blog.local}" ];
            volumes = [
              "/persist/containers/ws-blog/app:/app/data:U"
            ];
            environmentFiles = [ config.sops.templates.env_blog.path ];
            environments = {
              DJANGO_ALLOWED_HOSTS = "matheusplinta.com,www.matheusplinta.com,plinta.dev,www.plinta.dev";
              DJANGO_CSRF_TRUSTED_ORIGINS = "https://matheusplinta.com,https://www.matheusplinta.com,https://plinta.dev,https://www.plinta.dev";
            };
            dropCapabilities = [ "ALL" ];
            noNewPrivileges = true;
            readOnly = true;
            readOnlyTmpfs = true;
            tmpfses = [ "/tmp:rw,noexec,nosuid,nodev,size=64m,mode=1777" ];
            pidsLimit = 128;
            healthCmd = "python -c \"import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/healthz', timeout=3)\"";
            healthInterval = "30s";
            healthTimeout = "5s";
            healthStartPeriod = "30s";
            healthRetries = 3;
            healthOnFailure = "kill";
            notify = "healthy";
          };
        };

        ws-ots = {
          serviceConfig.Restart = "on-failure";
          containerConfig = {
            autoUpdate = "registry";
            image = "ghcr.io/mfplinta/ots-website:latest";
            userns = "auto";
            networks = [ "${networks.net_br0.ref}:ip=${addresses.ws-ots.local}" ];
            volumes = [
              "/persist/containers/ws-ots:/app/data:U"
            ];
            environmentFiles = [ config.sops.templates.env_ots.path ];
            environments = {
              DJANGO_ALLOWED_HOSTS = "optimaltech.us,www.optimaltech.us";
              DJANGO_CSRF_TRUSTED_ORIGINS = "https://optimaltech.us,https://www.optimaltech.us";
            };
            dropCapabilities = [ "ALL" ];
            noNewPrivileges = true;
            readOnly = true;
            readOnlyTmpfs = true;
            tmpfses = [ "/tmp:rw,noexec,nosuid,nodev,size=64m,mode=1777" ];
            pidsLimit = 128;
            healthCmd = "python -c \"import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/healthz', timeout=3)\"";
            healthInterval = "30s";
            healthTimeout = "5s";
            healthStartPeriod = "30s";
            healthRetries = 3;
            healthOnFailure = "kill";
            notify = "healthy";
          };
        };

        # --- Quartz ---
        quartz.containerConfig = {
          image = "docker.io/mfplinta016/dockerized-quartz:latest";
          userns = "auto";
          networks = [ "${networks.net_br0.ref}:ip=${addresses.quartz.local}" ];
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
          userns = "auto";
          networks = [ "${networks.net_br0.ref}:ip=${addresses.tmdb-addon.local}" ];
          environmentFiles = [ config.sops.templates.env_tmdb.path ];
        };

        # --- Stirling PDF ---
        stirling-pdf.containerConfig = {
          autoUpdate = "registry";
          image = "docker.stirlingpdf.com/stirlingtools/stirling-pdf:latest";
          userns = "auto";
          networks = [ "${networks.net_br0.ref}:ip=${addresses.stirling-pdf.local}" ];
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

        # --- Coturn ---
        coturn.containerConfig = {
          autoUpdate = "registry";
          image = "docker.io/coturn/coturn:latest";
          userns = "auto";
          networks = [ "${networks.net_br0.ref}:ip=${addresses.coturn.local}" ];
          environments = {
            #DETECT_EXTERNAL_IP = "yes";
          };
          volumes = [
            "${config.sops.templates.env_coturn.path}:/etc/turnserver.conf"
          ];
          exec = [
            "--external-ip=161.153.3.153"
            "--log-file=stdout"
            "--verbose"
            "--realm=plinta.dev"
            "--min-port=10000"
            "--max-port=20000"
            "--fingerprint"
            "--lt-cred-mech"
            "--listening-ip=0.0.0.0"
            "--listening-port=3478"
          ];
        };

        # --- Soularr ---
        # soularr.containerConfig = {
        #   autoUpdate = "registry";
        #   image = "docker.io/mrusse08/soularr:latest";
        #   userns = "auto";
        #   networks = [ "${networks.net_br0.ref}:ip=${addresses.soularr.local}" ];
        #   volumes = [
        #     "${config.sops.templates.env_soularr.path}:/data/config.ini:ro"
        #     "/persist/media/music:/downloads:ro"
        #   ];
        #   environments.SCRIPT_INTERVAL = "300";
        # };

        # --- Contractual ---
        contractual-app.containerConfig = {
          autoUpdate = "registry";
          image = "ghcr.io/mfplinta/contractual:latest";
          userns = "auto";
          networks = [ "${networks.net_br0.ref}:ip=${addresses.contractual-app.local}" ];
          volumes = [
            "/persist/containers/contractual/app:/app/data:U"
          ];
          environments = {
            DEBUG = "False";
            ALLOWED_HOSTS = "app.mastermovement.us";
            CSRF_TRUSTED_ORIGINS = "https://app.mastermovement.us";
          };
        };
      };
    };

  cfg.services.vmagent.enable = true;
  cfg.services.vmagent.logs.enable = true;
  cfg.services.vmagent.remoteWriteUrl = "http://${addresses.monitoring.local}:8428/api/v1/write";
  cfg.services.vmagent.extraScrapeConfigs = [
    {
      job_name = "caddy";
      scrape_interval = "15s";
      static_configs = [
        {
          targets = [ "${addresses.reverseProxy.local}:9101" ];
          labels.instance = config.networking.hostName;
        }
      ];
    }
  ];

  services.endlessh = {
    enable = true;
    port = 22;
    openFirewall = true;
  };

  services.fail2ban.enable = true;
  services.openssh.ports = [ 22000 ];
}
