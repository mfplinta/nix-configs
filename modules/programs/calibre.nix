{
  hmModule =
    {
      config,
      pkgs,
      lib,
      setMimeTypes,
      ...
    }:
    let
      inherit (lib) mkIf mkEnableOption;
      cfg = config.cfg.programs.calibre;
    in
    {
      options.cfg.programs.calibre = {
        enable = mkEnableOption "calibre";
      };

      config = mkIf cfg.enable {
        home.packages = with pkgs; [
          calibre
        ];

        xdg.mimeApps.defaultApplications = setMimeTypes "calibre-ebook-viewer.desktop" [
          "application/epub+zip"
        ];
      };
    };
}
