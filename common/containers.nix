{
  sysModule =
    { pkgs, ... }:
    {
      virtualisation.podman.enable = true;
      virtualisation.podman.dockerCompat = true;
      virtualisation.oci-containers.backend = "podman";
      environment.systemPackages = with pkgs; [
        podman-compose
        act
      ];
    };
}
