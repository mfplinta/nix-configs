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
  sops.templates.env_caddy = {
    mode = "0444";
    content = ''
      CF_API_KEY=${config.sops.placeholder.cf_api_key}
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
      inherit (config.virtualisation.quadlet) networks volumes;
    in
    {
      enable = true;
      networks = {
        net_vlan1.networkConfig = {
          driver = "macvlan";
          ipRanges = [ "10.0.1.211-10.0.1.213" ];
          gateways = [ "10.0.1.1" ];
          subnets = [ "10.0.1.0/24" ];
          networkDeleteOnStop = true;
        };
        net_vlan2.networkConfig = {
          driver = "macvlan";
          ipRanges = [ "10.0.2.211-10.0.2.213" ];
          gateways = [ "10.0.2.1" ];
          subnets = [ "10.0.2.0/24" ];
          networkDeleteOnStop = true;
        };
        net_vlan3.networkConfig = {
          driver = "macvlan";
          ipRanges = [ "10.0.3.211-10.0.3.213" ];
          gateways = [ "10.0.3.1" ];
          subnets = [ "10.0.3.0/24" ];
          networkDeleteOnStop = true;
        };
      };
      containers = {
        # --- Caddy ---
        caddy.containerConfig = {
          addCapabilities = [ "CAP_NET_RAW" "CAP_NET_BIND_SERVICE" "NET_ADMIN" ];
          image = "ghcr.io/caddybuilds/caddy-cloudflare:latest";
          networks = [ "podman" "${networks.net_vlan1.ref}:10.0.1.211" "${networks.net_vlan3.ref}:10.0.3.211" ];
          publishPorts = [ "80:80" "443:443" ];
          environmentFiles = [ config.sops.templates.env_caddy.path ];
          volumes = [ "${volumes.caddy_data.ref}:/data" "${volumes.caddy_file.ref}:/etc/caddy/Caddyfile" ];
        };

        # --- Home Assistant ---
        hass.containerConfig = {
          image = "ghcr.io/home-assistant/home-assistant:stable";
          addCapabilities = [ "CAP_NET_RAW" "CAP_NET_BIND_SERVICE" ];
          networks = [ "podman" "${networks.net_vlan1.ref}:10.0.1.212" "${networks.net_vlan2.ref}:10.0.2.212" ];
          publishPorts = [ "8123:8123" ];
          volumes = [
            "${volumes.hass_data.ref}:/config"
            "/etc/localtime:/etc/localtime:ro"
            "/run/dbus:/run/dbus:ro"
          ];
        };

        # --- Z-Wave JS UI ---
        zwavejs.containerConfig = {
          image = "zwavejs/zwave-js-ui:latest";
          networks = [ "podman" "${networks.net_vlan1.ref}:10.0.1.213" ];
          publishPorts = [ "8091:8091" ];
          volumes = [ "${volumes.zwavejs_data.ref}:/usr/src/app/store" ];
          devices = [ "/dev/serial/by-id/usb-Zooz_800_Z-Wave_Stick_533D004242-if00:/dev/serial/by-id/usb-Zooz_800_Z-Wave_Stick_533D004242-if00" ];
        };

        # --- Mosquitto ---
        mosquitto.containerConfig = {
          image = "eclipse-mosquitto:latest";
          networks = [ "podman" "${networks.net_vlan1.ref}:10.0.1.214" ];
          publishPorts = [ "1883:1883" ];
          volumes = [
            "${volumes.mosquitto_config.ref}:/mosquitto/config"
            "${volumes.mosquitto_data.ref}:/mosquitto/data"
            "${volumes.mosquitto_log.ref}:/mosquitto/log"
          ];
        };

        # --- ring-mqtt ---
        ring-mqtt.containerConfig = {
          image = "tsightler/ring-mqtt";
          networks = [ "podman" "${networks.net_vlan1.ref}:10.0.1.215" ];
          publishPorts = [ "8554:8554" ];
          volumes = [  "${volumes.ring_mqtt_data.ref}:/data" ];
        };

        # --- ESPHome ---
        esphome.containerConfig = {
          image = "ghcr.io/esphome/esphome:latest";
          networks = [  "podman" "${networks.net_vlan1.ref}:10.0.1.216" "${networks.net_vlan2.ref}:10.0.2.216" ];
          publishPorts = [ "6052:6052" ];
          volumes = [ "${volumes.esphome_data.ref}:/config" ];
        };
      };
      volumes = {
        # --- Caddy ---
        caddy_data.volumeConfig = {
          type = "bind";
          device = paths.source.caddy-data;
        };
        caddy_file.volumeConfig = {
          type = "bind";
          device = "${pkgs.writeText "Caddyfile" ''
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
          ''}";
        };

        # --- Home Assistant ---
        hass_data.volumeConfig = {
          type = "bind";
          device = paths.source.hass;
        };

        # --- Z-Wave JS UI ---
        zwavejs_data.volumeConfig = {
          type = "bind";
          device = paths.source.zwavejs;
        };

        # --- Mosquitto ---
        mosquitto_config.volumeConfig = {
          type = "bind";
          device = paths.source.mosquitto-config;
        };
        mosquitto_data.volumeConfig = {
          type = "bind";
          device = paths.source.mosquitto-data;
        };
        mosquitto_log.volumeConfig = {
          type = "bind";
          device = paths.source.mosquitto-log;
        };

        # --- ring-mqtt ---
        ring_mqtt_data.volumeConfig = {
          type = "bind";
          device = paths.source.ring-mqtt;
        };

        # --- ESPHome ---
        esphome_data.volumeConfig = {
          type = "bind";
          device = paths.source.esphome;
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
