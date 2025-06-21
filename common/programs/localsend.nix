{
  hmModule =
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.localsend
      ];
    };

  sysModule =
    { ... }:
    {
      networking.firewall.allowedTCPPorts = [ 53317 ];
      networking.firewall.allowedUDPPorts = [ 53317 ];
    };
}
