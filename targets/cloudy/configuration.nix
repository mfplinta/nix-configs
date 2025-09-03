{
  pkgs,
  lib,
  config,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
  ];

  boot.loader.timeout = 1;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [
    "net.ifnames=0"
    "boot.shell_on_fail"
    "panic=30"
    "boot.panic_on_fail"
  ];

  sops.defaultSopsFile = ./../secrets.yaml;
  sops.age.keyFile = "/root/.config/sops/age/keys.txt";
  sops.secrets.cf_api_key = {};
  sops.secrets.cloudy_http_auth_bcrypt = {};
  sops.templates.env_caddy = {
    mode = "0444";
    content = ''
      CF_API_KEY=${config.sops.placeholder.cf_api_key}
      HTTP_AUTH_PWD=${config.sops.placeholder.cloudy_http_auth_bcrypt}
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
        forwardPorts = [
          {
            destination = "192.168.100.11:80";
            proto = "tcp";
            sourcePort = 80;
          }
          {
            destination = "192.168.100.11:443";
            proto = "tcp";
            sourcePort = 443;
          }
        ];
      };
    };

  time.timeZone = "America/Denver";

  environment.systemPackages = with pkgs; [
    vim
    wget
    git
    htop
  ];

  systemd.tmpfiles.rules = [
    "d /persist/containers/caddy 0600 root root -"
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
      caddy = common // {
        hostAddress = "192.168.100.10";
        localAddress = "192.168.100.11";

        bindMounts."/var/lib/caddy:idmap" = {
          hostPath = "/persist/containers/caddy";
          isReadOnly = false;
        };

        bindMounts."${config.sops.templates.env_caddy.path}".isReadOnly = true;

        config =
          { ... }:
          {
            system.stateVersion = config.system.stateVersion;
            networking.firewall.enable = false;

            services.caddy = {
              enable = true;
              package = pkgs.caddy.withPlugins {
                plugins = [
                  "github.com/caddy-dns/cloudflare@v0.2.1"
                ];
                hash = "sha256-S1JN7brvH2KIu7DaDOH1zij3j8hWLLc0HdnUc+L89uU=";
              };
              environmentFile = config.sops.templates.env_caddy.path;
              configFile = pkgs.writeText "Caddyfile" ''
                {
                  admin off
                }

                *.matheusplinta.com {
                  tls {
                    dns cloudflare {env.CF_API_KEY}
                  }

                  @grafana host grafana.matheusplinta.com
                  handle @grafana {
                    reverse_proxy 192.168.101.11:3000
                  }

                  @victoriametrics host victoriametrics.matheusplinta.com
                  handle @victoriametrics {
                    basic_auth {
                      mfplinta {env.HTTP_AUTH_PWD}
                    }
                    reverse_proxy 192.168.101.11:8428
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
        hostAddress = "192.168.101.10";
        localAddress = "192.168.101.11";

        config =
          { ... }:
          {
            system.stateVersion = config.system.stateVersion;
            networking.firewall.enable = false;

            services.grafana = {
              enable = true;
              declarativePlugins = [
                pkgs.grafanaPlugins.victoriametrics-metrics-datasource
              ];
              settings.server = {
                http_addr = "0.0.0.0";
                http_port = 3000;
              };
            };

            services.victoriametrics = {
              enable = true;
              listenAddress = ":8428";
            };
          };
      };
    };

  services.openssh.enable = true;
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDO7lQ5/HFagyOrQKXT9IC1PqBm/Yvi3zThJ7Azawg3lb6FHKUms8FuR5vS5rkrRCaTrs8URHugirIMvXQYxmTMbU51jGsJcWPNfTPm/iWczYUVFHY5TY4BlviWMu0EzHA9pA5bcR8DGjEgJdloPwuQ6eOTda0x9HBNBT8Q0xbiXTjmcYwluqw3iI8Up54f5zR6nC0pMkKTHIjmSLzCnbCBFsZ+aIvtE339oLbQZ5B5Jlw0/lgV1m9/GTn/PUHbUPbgKW3MZ4/kCuqh62UvqdyMa2bjaqPZLfcrNkJSvT8xVxk4enKUfHj5VI1jwG6SJ6s6fc/FUHZJlt3wtGsw08XL ssh-key-2025-09-02"
  ];

  services.vmagent = {
    enable = true;
    remoteWrite = {
      url = "http://192.168.101.11:8428/api/v1/write";
    };
    prometheusConfig = {
      scrape_configs = [
        {
          job_name = "cloudy@node-exporter";
          scrape_interval = "60s";
          static_configs = [
            {
              targets = [ "127.0.0.1:9100" ];
              labels.type = "node";
            }
          ];
        }
      ];
    };
  };

  services.prometheus.exporters.node = {
    enable = true;
    port = 9100;
    enabledCollectors = [ "systemd" ];
  };
}
