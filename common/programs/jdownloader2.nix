{
  sysModule =
    { ... }:
    {
      systemd.tmpfiles.rules = [
        "d /home/matheus/Downloads 0755 matheus users -"
        "d /home/matheus/Downloads/JD 0755 matheus users -"
        "d /home/matheus/.config 0755 matheus users -"
        "d /home/matheus/.config/containers 0755 matheus users -"
        "d /home/matheus/.config/containers/jdownloader2 0755 matheus users -"
      ];

      virtualisation.oci-containers.containers = {
        jdownloader2 = {
          image = "jlesage/jdownloader-2";
          volumes = [
            "/home/matheus/Downloads/JD:/output"
            "/home/matheus/.config/containers/jdownloader2:/config"
          ];
          autoStart = true;
          ports = [
            "5800:5800"
          ];
        };
      };
    };
}