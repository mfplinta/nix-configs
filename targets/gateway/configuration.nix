{
  sysImport,
  private,
  ...
}:

let
  networkConfig = private.network;
  unboundViews =
    { networkConfig }:
    let
      inherit (builtins) attrNames attrValues foldl';

      getGeneralNames = dev: dev.names or [ ];
      getVlanNames = dev: vlanId: dev.vlan.${vlanId}.names or [ ];

      byVlan = foldl' (
        acc: dev:
        let
          vlanIds = attrNames dev.vlan;
          general = getGeneralNames dev;
        in
        foldl' (
          acc2: vlanId:
          let
            ip = dev.vlan.${vlanId}.address;
            specific = getVlanNames dev vlanId;
            names = general ++ specific;
            lines = map (n: ''"${n}. IN A ${ip}"'') names;
            prev = acc2.${vlanId} or [ ];
          in
          acc2 // { ${vlanId} = prev ++ lines; }
        ) acc vlanIds
      ) { } (attrValues networkConfig.device or { });

      mkView = vlanId: lines: {
        name = "vlan${vlanId}";
        view-first = true;
        local-data = lines;
      };

    in
    map (vlanId: mkView vlanId byVlan.${vlanId}) (attrNames byVlan);
in
{
  imports = [
    ./disko.nix
    ./hardware-configuration.nix

    (sysImport ../../common/base.nix)
    (sysImport ../../common/server.nix)
  ];

  boot.kernelParams = [ "net.ifnames=0" ];

  networking =
    let
      net = networkConfig.device.gateway;
    in
    {
      firewall.allowedTCPPorts = [ 53 ];
      firewall.allowedUDPPorts = [ 53 ];
      firewall.checkReversePath = "loose";
      useDHCP = false;
      nameservers = [ "1.1.1.1" ];
      defaultGateway = {
        address = net.vlan."1".gateway;
        interface = "eth0";
      };
      interfaces."eth0".ipv4.addresses = [
        {
          address = net.vlan."1".address;
          prefixLength = net.vlan."1".prefixLength;
        }
      ];
      interfaces."eth1".ipv4.addresses = [
        {
          address = net.vlan."2".address;
          prefixLength = net.vlan."2".prefixLength;
        }
      ];
      interfaces."eth2".ipv4.addresses = [
        {
          address = net.vlan."3".address;
          prefixLength = net.vlan."3".prefixLength;
        }
      ];
    };
  services.unbound = {
    enable = true;
    resolveLocalQueries = false;
    settings = {
      server = {
        prefetch = true;
        tls-system-cert = true;
        interface-automatic = true;
        access-control = [
          "10.0.0.0/8 allow"
          "127.0.0.0/8 allow"
          "::1/128 allow"
        ];
        access-control-view =
          let
            vlanIds = builtins.attrNames (networkConfig.topology.vlan or { });
          in
          (map (
            v:
            let
              subnet = networkConfig.topology.vlan.${v}.subnet;
            in
            "${subnet} vlan${v}"
          ) vlanIds)
          ++ [ "10.69.69.0/24 vlan3" ];

        hide-identity = true;
        module-config = "iterator";
      };

      forward-zone = [
        {
          name = "arpa.";
          forward-addr = "${networkConfig.topology.localnames-dns}@53";
          forward-no-cache = true;
        }
        {
          name = ".";
          forward-tls-upstream = true;
          forward-addr = networkConfig.topology.forward-dnses;
        }
      ];

      view = (unboundViews { inherit networkConfig; });
    };
  };
}
