{ 
  lib,
  pkgs,
  config,
  sysImport,
  ...
}:

let
  networkConfig = (import ./../../private/cfg.nix).network;
  unboundViews =
  { networkConfig }:
  let
    inherit (builtins) attrNames attrValues foldl';

    getGeneralNames = dev: dev.names or [];
    getVlanNames = dev: vlanId: dev.vlan.${vlanId}.names or [];

    byVlan =
      foldl' (acc: dev:
        let vlanIds = attrNames dev.vlan;
            general = getGeneralNames dev;
        in foldl' (acc2: vlanId:
          let
            ip       = dev.vlan.${vlanId}.address;
            specific = getVlanNames dev vlanId;
            names    = general ++ specific;
            lines    = map (n: ''local-data: "${n}. IN A ${ip}"'') names;
            prev     = acc2.${vlanId} or [];
          in
            acc2 // { ${vlanId} = prev ++ lines; }
        ) acc vlanIds
      ) {} (attrValues networkConfig.device or {});

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
    (sysImport ../../common/containers.nix)
  ];
  
  services.unbound = {
    enable = true;

    settings = {
      server = {
        interface = [ "127.0.0.1" "::1" ];
        access-control = [
          "127.0.0.0/8 allow"
          "::1 allow"
        ];

        hide-identity = true;
        hide-version = true;
        rrset-roundrobin = true;
      };

      stub-zone = [
        {
          name = "arpa";
          stub-addr = "${networkConfig.topology.localnames-dns}@53";  # <-- change if your router IP differs
        }
      ];

      forward-zone = [
        {
          name = ".";
          forward-addr = networkConfig.topology.forward-dnses;
        }
      ];

      view = (unboundViews { inherit networkConfig; });
    };
  };
}
