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
    source.matterhub = paths.root + "/matterhub";
  };
  networkConfig = (import ./../../private/cfg.nix).network;
in
{
  imports = [
    ./disko.nix
    ./hardware-configuration.nix

    (sysImport ../../common/base.nix)
    (sysImport ../../common/server.nix)
    (sysImport ../../common/containers.nix)
  ];

  sops.defaultSopsFile = ./../../private/secrets.yaml;
  sops.age.keyFile = "/root/.config/sops/age/keys.txt";
  sops.secrets.cf_api_key = {};
  sops.secrets.cloudy-http_auth_plain = {};
  sops.secrets.tiny-ha_token = {};
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
        useDHCP = false;
        vlans = {
          vlan1 = { id = 1; interface = nicName; };
          vlan2 = { id = 2; interface = nicName; };
          vlan3 = { id = 3; interface = nicName; };
        };
        interfaces = {
          vlan1.ipv4.addresses = [{
            address = net.vlan."1".address;
            prefixLength = net.vlan."1".prefixLength;
          }];
          vlan2.ipv4.addresses = [{
            address = net.vlan."2".address;
            prefixLength = net.vlan."2".prefixLength;
          }];
          vlan3.ipv4.addresses = [{
            address = net.vlan."3".address;
            prefixLength = net.vlan."3".prefixLength;
          }];
        };
        defaultGateway = {
          address = net.vlan."1".gateway;
        };
        nameservers = [ net.vlan."1".dns ];
      };

  virtualisation.quadlet =
    let
      inherit (config.virtualisation.quadlet) networks;
    in
    {
      enable = true;
      networks = {
        net_vlan1.networkConfig = {
          driver = "macvlan";
          ipRanges = [
            "${networkConfig.device.tiny-ha.vlan."1".address}-${networkConfig.device.tiny-matterhub.vlan."1".address}"
          ];
          gateways = [ networkConfig.topology.vlan."1".gateway ];
          subnets = [ networkConfig.topology.vlan."1".subnet ];
          options.parent = "vlan1";
        };
        net_vlan2.networkConfig = {
          driver = "macvlan";
          ipRanges = [
            "${networkConfig.device.tiny-ha.vlan."2".address}-${networkConfig.device.tiny-matterhub.vlan."2".address}"
          ];
          gateways = [ networkConfig.topology.vlan."2".gateway ];
          subnets = [ networkConfig.topology.vlan."2".subnet ];
          options.parent = "vlan2";
        };
      };
      containers = {
        # --- Caddy ---
        caddy.containerConfig = {
          addCapabilities = [ "CAP_NET_RAW" "CAP_NET_BIND_SERVICE" "NET_ADMIN" ];
          image = "ghcr.io/caddybuilds/caddy-cloudflare:latest";
          networks = [ "podman" ];
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
          ''}:/etc/caddy/Caddyfile" ];
        };

        # --- Home Assistant ---
        hass.containerConfig = {
          image = "ghcr.io/home-assistant/home-assistant:stable";
          addCapabilities = [ "CAP_NET_RAW" "CAP_NET_BIND_SERVICE" ];
          networks = [
            "podman"
            "${networks.net_vlan1.ref}:ip=${networkConfig.device.tiny-ha.vlan."1".address}"
            "${networks.net_vlan2.ref}:ip=${networkConfig.device.tiny-ha.vlan."2".address}"
          ];
          volumes = [
            "${paths.source.hass}:/config"
            "/etc/localtime:/etc/localtime:ro"
            "/run/dbus:/run/dbus:ro"
          ];
        };

        # --- Z-Wave JS UI ---
        zwavejs.containerConfig = {
          image = "zwavejs/zwave-js-ui:latest";
          volumes = [ "${paths.source.zwavejs}:/usr/src/app/store" ];
          devices = [ "/dev/serial/by-id/usb-Zooz_800_Z-Wave_Stick_533D004242-if00:/dev/serial/by-id/usb-Zooz_800_Z-Wave_Stick_533D004242-if00" ];
        };

        # --- Mosquitto ---
        mosquitto.containerConfig = {
          image = "eclipse-mosquitto:latest";
          publishPorts = [ "1883:1883" ];
          volumes = [
            "${paths.source.mosquitto-config}:/mosquitto/config"
            "${paths.source.mosquitto-data}:/mosquitto/data"
            "${paths.source.mosquitto-log}:/mosquitto/log"
          ];
        };

        # --- ring-mqtt ---
        ring-mqtt.containerConfig = {
          image = "tsightler/ring-mqtt";
          volumes = [  "${paths.source.ring-mqtt}:/data" ];
        };

        # --- ESPHome ---
        esphome.containerConfig = {
          image = "ghcr.io/esphome/esphome:latest";
          networks = [
            "podman"
            "${networks.net_vlan1.ref}:ip=${networkConfig.device.tiny-esphome.vlan."1".address}"
            "${networks.net_vlan2.ref}:ip=${networkConfig.device.tiny-esphome.vlan."2".address}"
          ];
          #publishPorts = [ "6052:6052" ];
          volumes = [ "${paths.source.esphome}:/config" ];
        };

        # --- Matterhub ---
        matterhub.containerConfig = {
          image = "ghcr.io/t0bst4r/home-assistant-matter-hub:latest";
          networks = [
            "podman"
            "${networks.net_vlan1.ref}:ip=${networkConfig.device.tiny-matterhub.vlan."1".address}"
            "${networks.net_vlan2.ref}:ip=${networkConfig.device.tiny-matterhub.vlan."2".address}"
          ];
          environmentFiles = [ config.sops.templates.env_matterhub.path ];
          environments.HAMH_HOME_ASSISTANT_URL = "http://hass:8123";
          volumes = [ "${paths.source.matterhub}:/data" ];
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
