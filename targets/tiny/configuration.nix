{
  lib,
  pkgs,
  config,
  sysImport,
  ...
}:

let
  ### Constants
  nicName = "enp1s0";
  paths = {
    root = "/persist";
    source.caddy-cloudflare-token = paths.root + "/caddy/cloudflare.env";
    source.caddy-data = paths.root + "/caddy/data";
    source.hass = paths.root + "/hass";
    source.zwavejs = paths.root + "/zwavejs";
    source.mosquitto-config = paths.root + "/mosquitto/config";
    source.mosquitto-data = paths.root + "/mosquitto/data";
    source.mosquitto-log = paths.root + "/mosquitto/log";
    source.ring-mqtt = paths.root + "/ring-mqtt";
    source.esphome = paths.root + "/esphome";
    source.matter-hub = paths.root + "/matterhub";
  };
in
{
  imports = [
    ./disko.nix
    ./hardware-configuration.nix

    (sysImport ../../common/base.nix)
    (sysImport ../../common/server.nix)
    (sysImport ../../common/containers.nix)
  ];

  sops.defaultSopsFile = ./../secrets.yaml;
  sops.age.keyFile = "/root/.config/sops/age/keys.txt";
  sops.secrets.cf_api_key = {};
  sops.secrets.cloudy-http_auth_plain = {};
  sops.secrets.tiny-ha_access_token = {};
  sops.templates.env_caddy = {
    mode = "0444";
    content = ''
      CF_API_KEY=${config.sops.placeholder.cf_api_key}
    '';
  };
  sops.templates.env_matter-hub = {
    mode = "0444";
    content = ''
      HAMH_HOME_ASSISTANT_ACCESS_TOKEN=${config.sops.placeholder.tiny-ha_access_token}
    '';
  };

  networking = {
    useDHCP = false;
    vlans = {
      vlan1 = { id = 1; interface = nicName; };
      vlan2 = { id = 2; interface = nicName; };
      vlan3 = { id = 3; interface = nicName; };
    };
    interfaces = {
      vlan1.ipv4.addresses = [{ address = "10.0.1.210"; prefixLength = 24; }];
      vlan2.ipv4.addresses = [{ address = "10.0.2.210"; prefixLength = 24; }];
      vlan3.ipv4.addresses = [{ address = "10.0.3.210"; prefixLength = 24; }];
    };
    defaultGateway = {
      address = "10.0.1.1";
    };
    nameservers = [ "10.0.1.2" ];
  };

  virtualisation.quadlet =
    let
      inherit (config.virtualisation.quadlet) networks;
    in
    {
      enable = true;
      autoUpdate.enable = true;
      networks = {
        net_vlan1.networkConfig = {
          driver = "macvlan";
          ipRanges = [ "10.0.1.211-10.0.1.214" ];
          gateways = [ "10.0.1.1" ];
          subnets = [ "10.0.1.0/24" ];
          options.parent = "vlan1";
        };
        net_vlan2.networkConfig = {
          driver = "macvlan";
          ipRanges = [ "10.0.2.211-10.0.2.214" ];
          gateways = [ "10.0.2.1" ];
          subnets = [ "10.0.2.0/24" ];
          options.parent = "vlan2";
        };
        net_vlan3.networkConfig = {
          driver = "macvlan";
          ipRanges = [ "10.0.3.211-10.0.3.213" ];
          gateways = [ "10.0.3.1" ];
          subnets = [ "10.0.3.0/24" ];
          options.parent = "vlan3";
        };
      };
      containers = {
        # --- Caddy ---
        caddy.containerConfig = {
          addCapabilities = [ "CAP_NET_RAW" "CAP_NET_BIND_SERVICE" "NET_ADMIN" ];
          image = "ghcr.io/caddybuilds/caddy-cloudflare:latest";
          networks = [ "podman" "${networks.net_vlan1.ref}:ip=10.0.1.211" "${networks.net_vlan3.ref}:ip=10.0.3.211" ];
          publishPorts = [ "80:80" "443:443" ];
          environmentFiles = [ config.sops.templates.env_caddy.path ];
          volumes = [ "${paths.source.caddy-data}:/data" "${pkgs.writeText "Caddyfile" ''
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

              @esphome host esphome.matheusplinta.com
              handle @esphome {
                reverse_proxy esphome:6052
              }

              handle {
                abort
              }
            }
          ''}:/etc/caddy/Caddyfile" ];
        };

        # --- Home Assistant ---
        hass.containerConfig = {
          autoUpdate = "registry";
          image = "ghcr.io/home-assistant/home-assistant:2025.11";
          addCapabilities = [ "CAP_NET_RAW" "CAP_NET_BIND_SERVICE" ];
          networks = [ "podman" "${networks.net_vlan1.ref}:ip=10.0.1.212" "${networks.net_vlan2.ref}:ip=10.0.2.212" ];
          publishPorts = [ "8123:8123" ];
          volumes = [
            "${paths.source.hass}:/config"
            "/etc/localtime:/etc/localtime:ro"
            "/run/dbus:/run/dbus:ro"
          ];
        };

        # --- Z-Wave JS UI ---
        zwavejs.containerConfig = {
          autoUpdate = "registry";
          image = "docker.io/zwavejs/zwave-js-ui:11";
          publishPorts = [ "8091:8091" ];
          volumes = [ "${paths.source.zwavejs}:/usr/src/app/store" ];
          devices = [ "/dev/serial/by-id/usb-Zooz_800_Z-Wave_Stick_533D004242-if00:/dev/serial/by-id/usb-Zooz_800_Z-Wave_Stick_533D004242-if00" ];
        };

        # --- Mosquitto ---
        mosquitto.containerConfig = {
          autoUpdate = "registry";
          image = "docker.io/eclipse-mosquitto:2";
          publishPorts = [ "1883:1883" ];
          volumes = [
            "${paths.source.mosquitto-config}:/mosquitto/config"
            "${paths.source.mosquitto-data}:/mosquitto/data"
            "${paths.source.mosquitto-log}:/mosquitto/log"
          ];
        };

        # --- ring-mqtt ---
        ring-mqtt.containerConfig = {
          autoUpdate = "registry";
          image = "docker.io/tsightler/ring-mqtt:latest";
          publishPorts = [ "8554:8554" ];
          volumes = [  "${paths.source.ring-mqtt}:/data" ];
        };

        # --- ESPHome ---
        esphome.containerConfig = {
          autoUpdate = "registry";
          image = "ghcr.io/esphome/esphome:stable";
          networks = [ "podman" "${networks.net_vlan1.ref}:ip=10.0.1.213" "${networks.net_vlan2.ref}:ip=10.0.2.213" ];
          publishPorts = [ "6052:6052" ];
          volumes = [ "${paths.source.esphome}:/config" ];
        };

        # --- Matter Hub ---
        matter-hub.containerConfig = {
          autoUpdate = "registry";
          image = "ghcr.io/t0bst4r/home-assistant-matter-hub:latest";
          networks = [ "podman" "${networks.net_vlan1.ref}:ip=10.0.1.214" "${networks.net_vlan2.ref}:ip=10.0.2.214" ];
          environmentFiles = [ config.sops.templates.env_matter-hub.path ];
          environments.HAMH_HOME_ASSISTANT_URL = "http://hass:8123/";
          environments.HAMH_LOG_LEVEL = "info";
          environments.HAMH_HTTP_PORT = "8482";
          volumes = [ "${paths.source.matter-hub}:/data" ];
        };
      };
    };

  systemd.tmpfiles.rules = with builtins; map (path: "d ${path} 0755 root root -") (
    attrValues paths.source
  ); 

  services.openssh.settings.PermitRootLogin = "yes";

  myCfg.vmagentEnable = true;
  myCfg.vmagentRemoteWriteUrl = "https://victoriametrics.matheusplinta.com/api/v1/write";
  myCfg.vmagentUsername = "mfplinta";
  myCfg.vmagentPasswordFile = config.sops.secrets.cloudy-http_auth_plain.path;
}
