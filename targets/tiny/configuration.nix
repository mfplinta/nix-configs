{
  pkgs,
  config,
  sysImport,
  private,
  ...
}:

let
  ### Constants
  nicName = "enp1s0";
  networkConfig = private.network;
  paths = {
    root = "/persist";
    source.caddy-data = paths.root + "/caddy/data";
    source.hass = paths.root + "/hass";
    source.zwavejs = paths.root + "/zwavejs";
    source.mosquitto-config = paths.root + "/mosquitto/config";
    source.mosquitto-data = paths.root + "/mosquitto/data";
    source.mosquitto-log = paths.root + "/mosquitto/log";
    source.ring-mqtt = paths.root + "/ring-mqtt";
    source.esphome = paths.root + "/esphome";
    source.matterhub = paths.root + "/matterhub";
  };
in
{
  imports = [
    ./disko.nix
    ./hardware-configuration.nix

    (sysImport ../../common/base.nix)
    (sysImport ../../common/server.nix)
  ];

  sops.defaultSopsFile = private.secretsFile;
  sops.age.keyFile = "/root/.config/sops/age/keys.txt";
  sops.secrets.cf_api_key = { };
  sops.secrets.cloudy-http_auth_plain = { };
  sops.secrets.tiny-ha_token = { };
  sops.templates.env_caddy = {
    mode = "0444";
    content = ''
      CF_API_KEY=${config.sops.placeholder.cf_api_key}
    '';
  };
  sops.templates.env_matterhub = {
    mode = "0444";
    content = ''
      HAMH_HOME_ASSISTANT_ACCESS_TOKEN=${config.sops.placeholder.tiny-ha_token}
    '';
  };

  networking =
    let
      net = networkConfig.device.tiny;
    in
    {
      firewall.allowedTCPPorts = [
        80
        443
      ];
      firewall.checkReversePath = "loose";
      useDHCP = false;
      vlans = {
        vlan1 = {
          id = 1;
          interface = nicName;
        };
        vlan2 = {
          id = 2;
          interface = nicName;
        };
        vlan3 = {
          id = 3;
          interface = nicName;
        };
      };
      interfaces = {
        vlan1.ipv4.addresses = [
          {
            address = net.vlan."1".address;
            prefixLength = net.vlan."1".prefixLength;
          }
        ];
        vlan2.ipv4.addresses = [
          {
            address = net.vlan."2".address;
            prefixLength = net.vlan."2".prefixLength;
          }
        ];
        vlan3.ipv4.addresses = [
          {
            address = net.vlan."3".address;
            prefixLength = net.vlan."3".prefixLength;
          }
        ];
      };
      defaultGateway = {
        address = net.vlan."1".gateway;
      };
      nameservers = [ net.vlan."1".dns ];
    };

  cfg.virtualisation.quadlet.enable = true;
  virtualisation.quadlet =
    let
      inherit (config.virtualisation.quadlet) networks;
    in
    {
      networks = {
        net_vlan1.networkConfig = {
          driver = "macvlan";
          gateways = [ networkConfig.topology.vlan."1".gateway ];
          subnets = [ networkConfig.topology.vlan."1".subnet ];
          options.parent = "vlan1";
          options.metric = "1";
        };
        net_vlan2.networkConfig = {
          driver = "macvlan";
          gateways = [ networkConfig.topology.vlan."2".gateway ];
          subnets = [ networkConfig.topology.vlan."2".subnet ];
          options.parent = "vlan2";
        };
      };
      containers = {
        # --- Caddy ---
        caddy.containerConfig = {
          addCapabilities = [
            "CAP_NET_RAW"
            "CAP_NET_BIND_SERVICE"
            "NET_ADMIN"
          ];
          image = "ghcr.io/caddybuilds/caddy-cloudflare:latest";
          userns = "auto";
          networks = [ "podman" ];
          publishPorts = [
            "80:80"
            "443:443"
          ];
          environmentFiles = [ config.sops.templates.env_caddy.path ];
          volumes = [
            "${paths.source.caddy-data}:/data:U"
            "${pkgs.writeText "Caddyfile" ''
              *.matheusplinta.com {
                tls {
                  issuer acme {
                    dns cloudflare {env.CF_API_KEY}
                    resolvers 8.8.8.8
                  }
                }
                
                @hass host ha.matheusplinta.com
                handle @hass {
                  reverse_proxy hass:8123
                }

                @zwavejs host zwavejs.matheusplinta.com
                handle @zwavejs {
                  reverse_proxy zwavejs:8091
                }

                @esphome host esphome.matheusplinta.com
                handle @esphome {
                  reverse_proxy esphome:6052
                }

                @matterhub host matterhub.matheusplinta.com
                handle @matterhub {
                  reverse_proxy matterhub:8482
                }

                handle {
                  abort
                }
              }
            ''}:/etc/caddy/Caddyfile:ro"
          ];
        };

        # --- Home Assistant ---
        hass.containerConfig = {
          autoUpdate = "registry";
          image = "ghcr.io/home-assistant/home-assistant:2025.12";
          addCapabilities = [
            "CAP_NET_RAW" # Needed for ping
          ];
          userns = "auto";
          networks = [
            "podman"
            "${networks.net_vlan1.ref}:ip=${networkConfig.device.tiny-ha.vlan."1".address}"
            "${networks.net_vlan2.ref}:ip=${networkConfig.device.tiny-ha.vlan."2".address}"
          ];
          volumes = [
            "${paths.source.hass}:/config:U"
            "/etc/localtime:/etc/localtime:ro"
            "/run/dbus:/run/dbus:ro"
          ];
        };

        # --- Z-Wave JS UI ---
        zwavejs.containerConfig = {
          autoUpdate = "registry";
          image = "docker.io/zwavejs/zwave-js-ui:latest";
          userns = "auto";
          volumes = [ "${paths.source.zwavejs}:/usr/src/app/store:U" ];
          devices = [
            "/dev/serial/by-id/usb-Zooz_800_Z-Wave_Stick_533D004242-if00:/dev/serial/by-id/usb-Zooz_800_Z-Wave_Stick_533D004242-if00"
          ];
        };

        # --- Mosquitto ---
        mosquitto.containerConfig = {
          autoUpdate = "registry";
          image = "docker.io/eclipse-mosquitto:latest";
          userns = "auto";
          volumes = [
            "${paths.source.mosquitto-config}:/mosquitto/config:U"
            "${paths.source.mosquitto-data}:/mosquitto/data:U"
            "${paths.source.mosquitto-log}:/mosquitto/log:U"
          ];
        };

        # --- ring-mqtt ---
        ring-mqtt.containerConfig = {
          autoUpdate = "registry";
          image = "docker.io/tsightler/ring-mqtt";
          userns = "auto";
          volumes = [ "${paths.source.ring-mqtt}:/data:U" ];
        };

        # --- ESPHome ---
        esphome.containerConfig = {
          autoUpdate = "registry";
          image = "ghcr.io/esphome/esphome:latest";
          userns = "auto";
          networks = [
            "podman"
            "${networks.net_vlan1.ref}:ip=${networkConfig.device.tiny-esphome.vlan."1".address}"
            "${networks.net_vlan2.ref}:ip=${networkConfig.device.tiny-esphome.vlan."2".address}"
          ];
          volumes = [ "${paths.source.esphome}:/config:U" ];
        };

        # --- Matterhub ---
        matterhub.containerConfig = {
          image = "ghcr.io/t0bst4r/home-assistant-matter-hub:latest";
          userns = "auto";
          networks = [
            "podman"
            "${networks.net_vlan1.ref}:ip=${networkConfig.device.tiny-matterhub.vlan."1".address}"
            "${networks.net_vlan2.ref}:ip=${networkConfig.device.tiny-matterhub.vlan."2".address}"
          ];
          environmentFiles = [ config.sops.templates.env_matterhub.path ];
          environments.HAMH_HOME_ASSISTANT_URL = "http://hass:8123";
          volumes = [ "${paths.source.matterhub}:/data:U" ];
        };
      };
    };

  systemd.tmpfiles.rules =
    with builtins;
    map (path: "d ${path} 0755 root root -") (attrValues paths.source);

  services.openssh.settings.PermitRootLogin = "yes";

  cfg.services.vmagent = {
    enable = true;
    remoteWriteUrl = "https://victoriametrics.matheusplinta.com/api/v1/write";
    username = "mfplinta";
    passwordFile = config.sops.secrets.cloudy-http_auth_plain.path;
  };
}
