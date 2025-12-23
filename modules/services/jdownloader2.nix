{
  hmModule =
    { inputs, ... }:
    {
      imports = [
        inputs.quadlet-nix.homeManagerModules.quadlet
      ];

      systemd.user.tmpfiles.rules = [
        "d %h/Downloads/JD 0755 matheus users -"
        "d %h/.config/containers/jdownloader2 0755 matheus users -"
      ];

      virtualisation.quadlet.containers.jdownloader2 = {
        autoStart = true;
        containerConfig = {
          image = "jlesage/jdownloader-2";
          volumes = [
            "%h/Downloads/JD:/output"
            "%h/.config/containers/jdownloader2:/config"
          ];
          publishPorts = [ "5800:5800" ];
        };
      };
    };
}
