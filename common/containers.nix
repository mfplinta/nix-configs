{
  sysModule =
    { pkgs, ... }:
    {
      virtualisation.podman.enable = true;
      virtualisation.podman.defaultNetwork.settings.dns_enabled = true;
      virtualisation.podman.dockerCompat = true;
      environment.systemPackages = with pkgs; [
        podman-compose
      ];
    };
}
