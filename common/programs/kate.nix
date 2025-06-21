{
  hmModule =
    { pkgs, ... }:
    {
      xdg.mimeApps.defaultApplications =
        let
          mkEntries =
            types:
            builtins.listToAttrs (
              map (type: {
                name = type;
                value = [ "org.kde.kate.desktop" ];
              }) types
            );
        in
        mkEntries [
          "application/octet-stream"
          "text/plain"
        ];

      home.packages = [
        pkgs.kdePackages.kate
      ];
    };
}
