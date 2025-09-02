{
  lib,
  pkgs,
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
  ];

  boot.loader.grub.enable = true;
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.efiInstallAsRemovable = true;

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

  time.timeZone = "America/Denver";
  i18n.defaultLocale = "en_US.UTF-8";

  environment.systemPackages = with pkgs; [
    vim
    wget
    curl
    git
    pciutils
    htop
    smartmontools
    netcat-gnu
    unzip
  ];
  
  virtualisation.podman.enable = true;

  virtualisation.podman.defaultNetwork.settings.dns_enabled = true;
  systemd.services.create-podman-network = {
    serviceConfig.Type = "oneshot";
    wantedBy = [ "podman-hass.service" "podman-esphome.service" ];
    script = ''
      ${pkgs.podman}/bin/podman network exists net_hass_1 || \
      ${pkgs.podman}/bin/podman network create --driver=macvlan --ip-range=10.0.1.211-10.0.1.212 --gateway=10.0.1.1 --subnet=10.0.1.0/24 -o parent=vlan1 net_hass_1
      ${pkgs.podman}/bin/podman network exists net_hass_2 || \
      ${pkgs.podman}/bin/podman network create --driver=macvlan --ip-range=10.0.2.211-10.0.2.212 --gateway=10.0.2.1 --subnet=10.0.2.0/24 -o parent=vlan2 net_hass_2
    '';
  };

  virtualisation.oci-containers.backend = "podman";
  virtualisation.oci-containers.containers =  
  let
    TZ = "America/Denver";
  in
  {
    caddy = {
      autoStart = true;
      image = "ghcr.io/caddybuilds/caddy-cloudflare:latest";
      environment = { inherit TZ; };
      environmentFiles = [ paths.source.caddy-cloudflare-token ];
      extraOptions = [ "--cap-add=NET_ADMIN" ];
      volumes = [
        (paths.source.caddy-data + ":/data")
        (pkgs.writeText "Caddyfile" ''
          *.matheusplinta.com {
            tls {
              issuer acme {
                dns cloudflare {env.CLOUDFLARE_API_TOKEN}
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
        '' + ":/etc/caddy/Caddyfile")
      ];
      ports = [ "80:80" "443:443" ];
    };
    hass = {
      autoStart = true;
      image = "ghcr.io/home-assistant/home-assistant:stable";
      environment = { inherit TZ; };
      extraOptions = [
        "--cap-add=CAP_NET_RAW,CAP_NET_BIND_SERVICE"
        "--network=podman"
        "--network=net_hass_1:ip=10.0.1.211"
        "--network=net_hass_2:ip=10.0.2.211"
      ];
      volumes = [
        (paths.source.hass + ":/config")
        "/etc/localtime:/etc/localtime:ro"
        "/run/dbus:/run/dbus:ro"
      ];
      ports = [ "8123:8123" ];
    };
    zwavejs = {
      autoStart = true;
      image = "zwavejs/zwave-js-ui:latest";
      environment = { inherit TZ; };
      volumes = [
        (paths.source.zwavejs + ":/usr/src/app/store")
      ];
      devices = [
        "/dev/serial/by-id/usb-Zooz_800_Z-Wave_Stick_533D004242-if00:/dev/serial/by-id/usb-Zooz_800_Z-Wave_Stick_533D004242-if00"
      ];
      ports = [ "8091:8091" ];
    };
    mosquitto = {
      autoStart = true;
      image = "eclipse-mosquitto:latest";
      environment = { inherit TZ; };
      volumes = [
        (paths.source.mosquitto-config + ":/mosquitto/config")
        (paths.source.mosquitto-data + ":/mosquitto/data")
        (paths.source.mosquitto-log + ":/mosquitto/log")
      ];
      ports = [ "1883:1883" ];
    };
    ring-mqtt = {
      autoStart = true;
      image = "tsightler/ring-mqtt";
      environment = { inherit TZ; };
      volumes = [ (paths.source.ring-mqtt + ":/data") ];
      ports = [ "8554:8554" ];
    };
    esphome = {
      autoStart = true;
      image = "ghcr.io/esphome/esphome:latest";
      environment = { inherit TZ; };
      extraOptions = [
        "--network=podman"
        "--network=net_hass_1:ip=10.0.1.212"
        "--network=net_hass_2:ip=10.0.2.212"
      ];
      volumes = [ (paths.source.esphome + ":/config") ];
      ports = [ "6052:6052" ];
    };
  };
 
  systemd.tmpfiles.rules = with builtins; map (path: "d ${path} 0755 root root -") (
    attrValues paths.source
  ); 

  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "yes";
  services.openssh.settings.Macs = lib.mkOptionDefault [
    "hmac-sha2-512"
  ];
}
