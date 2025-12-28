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
      cfg = config.cfg.programs.okular;
    in
    {
      options.cfg.programs.okular = {
        enable = mkEnableOption "okular";
      };

      config = mkIf cfg.enable {
        xdg.mimeApps.defaultApplications = setMimeTypes "okularApplication_pdf.desktop" [
          "application/pdf"
        ];

        home.packages = [
          pkgs.unstable.kdePackages.okular
        ];
      };
    };
}
