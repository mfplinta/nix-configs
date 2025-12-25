{
  pkgs,
  lib,
  config,
  sysImport,
  private,
  ...
}:

let
  hostNic = "eth0";
  hostAddress = "10.0.0.104";
  bridgeAddress = "192.168.100.1";
  hostConfig = config;
  containerNames =
    (builtins.attrNames config.containers)
    ++ (builtins.attrNames config.virtualisation.quadlet.containers);
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
          proto = "tcp";
          sourcePort = 51820;
        }
        {
          destination = "${addresses.reverseProxy.local}:51820";
          proto = "udp";
          sourcePort = 51820;
        }
      ];
    };
    firewall.enable = true;
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
          ];

          config = lib.mkMerge [
            commonConfig
            (removeAttrs extra [ "imports" ])
          ];
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
                in
                pkgs.writeText "Caddyfile" ''
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

                  (cf) {
                    tls {
                      dns cloudflare {env.CF_API_KEY}
                      resolvers 1.1.1.1
                    }
                  }

                  (tunneled) {
                    header_up X-Forwarded-For {http.request.header.CF-Connecting-IP}
                  }

                  http://matheusplinta.com, https://matheusplinta.com {
                    import cf
                    redir https://www.matheusplinta.com{uri} permanent
                  }

                  *.matheusplinta.com {
                    import cf
                    @debug host debug.matheusplinta.com
                    handle @debug {
                      import bot_block
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
                        reverse_proxy ${addresses.quartz.local}:80
                      }
                      reverse_proxy ${addresses.ws-blog.local}:8000 {
                        import tunneled
                      }
                    }

                    @grafana host grafana.matheusplinta.com
                    handle @grafana {
                      import bot_block
                      reverse_proxy ${addresses.monitoring.local}:3000
                    }

                    @victoriametrics host victoriametrics.matheusplinta.com
                    handle @victoriametrics {
                      import bot_block
                      basic_auth {
                        mfplinta {env.HTTP_AUTH_PWD}
                      }
                      reverse_proxy ${addresses.monitoring.local}:8428
                    }

                    @gitea host gitea.matheusplinta.com
                    handle @gitea {
                      import bot_block
                      reverse_proxy ${addresses.gitea.local}:3000
                    }

                    @ha host ha.matheusplinta.com
                    handle @ha {
                      import bot_block
                      reverse_proxy https://ha.matheusplinta.com
                    }

                    @nextcloud host nextcloud.matheusplinta.com
                    handle @nextcloud {
                      import bot_block
                      reverse_proxy ${addresses.nextcloud.local}:8000
                    }

                    @nextcloud-ds host nextcloud-ds.matheusplinta.com
                    handle @nextcloud-ds {
                      import bot_block
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
                      import bot_block
                      reverse_proxy ${addresses.tmdb-addon.local}:1337
                    }

                    @pdf host pdf.matheusplinta.com
                    handle @pdf {
                      import bot_block
                      reverse_proxy ${addresses.stirling-pdf.local}:8080

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
                      import bot_block
                      reverse_proxy ${addresses.vaultwarden.local}:8222
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
                    @www host www.mastermovement.us
                    handle @www {
                      reverse_proxy ${addresses.ws-mastermovement.local}:8000 {
                        import tunneled
                      }
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
        localAddress = addresses.ws-blog.localWithSubnet;

        bindMounts."${config.sops.templates.env_blog.path}".isReadOnly = true;
        bindMounts."/app:idmap" = {
          hostPath = "/persist/containers/ws-blog/app";
          isReadOnly = false;
        };

        config = commonConfigWith {
          cfg.services.django-website = {
            enable = true;
            appName = "matheusplintacom";
            envFile = config.sops.templates.env_blog.path;
          };
        };
      };

      ws-ots = commonWith {
        localAddress = addresses.ws-ots.localWithSubnet;

        bindMounts."${config.sops.templates.env_ots.path}".isReadOnly = true;
        bindMounts."/app:idmap" = {
          hostPath = "/persist/containers/ws-ots";
          isReadOnly = false;
        };

        config = commonConfigWith {
          cfg.services.django-website = {
            enable = true;
            appName = "otswebsite";
            envFile = config.sops.templates.env_ots.path;
          };
        };
      };

      ws-mastermovement = commonWith {
        localAddress = addresses.ws-mastermovement.localWithSubnet;

        bindMounts."${config.sops.templates.env_mastermovement.path}".isReadOnly = true;
        bindMounts."/app:idmap" = {
          hostPath = "/persist/containers/ws-mastermovement";
          isReadOnly = false;
        };

        config = commonConfigWith {
          cfg.services.django-website = {
            enable = true;
            appName = "mastermovement";
            envFile = config.sops.templates.env_mastermovement.path;
          };
        };
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
              config.DOMAIN = "https://vaultwarden.matheusplinta.com";
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
              settings.enabledPreviewProviders = map (type: "OC\\Preview\\${type}") [
                "BMP"
                "GIF"
                "JPEG"
                "Krita"
                "MarkDown"
                "MP3"
                "OpenDocument"
                "PNG"
                "TXT"
                "XBitmap"
                "Movie"
                "MSOffice2003"
                "MSOffice2007"
                "MSOfficeDoc"
                "PDF"
                "Photoshop"
                "SVG"
                "TIFF"
                "HEIC"
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

  virtualisation.quadlet =
    let
      inherit (config.virtualisation.quadlet) networks;
    in
    {
      networks = {
        net_br0.networkConfig = {
          driver = "macvlan";
          gateways = [ "192.168.100.1" ];
          subnets = [ "192.168.100.0/24" ];
          options.parent = "br0";
        };
      };
      containers = {
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
      };
    };

  cfg.services.crowdsec.enable = true;
  cfg.services.crowdsec.tokenFile = config.sops.secrets.cloudy-crowdsec_token.path;

  services.endlessh = {
    enable = true;
    port = 22;
    openFirewall = true;
  };

  services.openssh.ports = [ 22000 ];

  cfg.services.vmagent.enable = true;
  cfg.services.vmagent.remoteWriteUrl = "http://${addresses.monitoring.local}:8428/api/v1/write";
}
