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
      cfg = config.cfg.programs.onlyoffice;
      officeFonts = pkgs.symlinkJoin {
        name = "onlyoffice-fonts";
        paths = with pkgs; [
          corefonts
          vista-fonts
        ];
      };
    in
    {
      options.cfg.programs.onlyoffice = {
        enable = mkEnableOption "onlyoffice";
      };

      config = mkIf cfg.enable {
        home.packages = [ pkgs.onlyoffice-desktopeditors ];

        xdg.dataFile."fonts/onlyoffice" = {
          source = "${officeFonts}/share/fonts";
          recursive = true;
        };

        xdg.mimeApps.defaultApplications = setMimeTypes "onlyoffice-desktopeditors.desktop" [
          "application/vnd.ms-excel"
          "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
          "application/vnd.ms-excel.template.macroEnabled.12"
          "application/vnd.openxmlformats-officedocument.spreadsheetml.template"
          "application/msword"
          "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
          "application/vnd.ms-powerpoint"
          "application/vnd.openxmlformats-officedocument.presentationml.presentation"
          "application/vnd.oasis.opendocument.presentation"
          "application/vnd.oasis.opendocument.spreadsheet"
          "application/vnd.oasis.opendocument.text"
          "text/csv"
        ];

      };
    };
}
