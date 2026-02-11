{
  sysModule =
    { pkgs, ... }:
    {
      virtualisation.podman.enable = true;
      virtualisation.podman.defaultNetwork.settings.dns_enabled = true;
      environment.systemPackages = with pkgs; [
        podman-compose
        act
      ];
      virtualisation.docker.enable = true; # Needed for act
      virtualisation.docker.rootless = {
        enable = true;
        setSocketVariable = true;
      };
    };
}
