{
  hmModule =
    { config, pkgs, lib, setMimeTypes, ... }:
    let
      inherit (lib) mkIf mkEnableOption;
      cfg = config.cfg.programs.nomacs;
    in
    {
      options.cfg.programs.nomacs = {
        enable = mkEnableOption "nomacs";
      };

      config = mkIf cfg.enable {
        xdg.mimeApps.defaultApplications = setMimeTypes "org.nomacs.ImageLounge.desktop" [
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
    };
}