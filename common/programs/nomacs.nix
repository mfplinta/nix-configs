{
  hmModule =
    { pkgs, wrapper-manager, ... }:
    {
      xdg.mimeApps.enable = true;
      xdg.mimeApps.defaultApplications =
        let
          imageViewer = "org.nomacs.ImageLounge.desktop";
          mkEntries =
            types:
            builtins.listToAttrs (
              map (type: {
                name = type;
                value = [ imageViewer ];
              }) types
            );
        in
        mkEntries [
          "image/bmp"
          "image/gif"
          "image/jpeg"
          "image/png"
          "image/vnd.adobe.photoshop"
          "image/tiff"
          "image/webp"
        ];

      home.packages = [
        pkgs.nomacs
      ];
    };

  sysModule =
    { pkgs, ... }:
    {
      # Nothing
    };
}
