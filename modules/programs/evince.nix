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
      cfg = config.cfg.programs.evince;
    in
    {
      options.cfg.programs.evince = {
        enable = mkEnableOption "evince";
      };
      config = mkIf cfg.enable {
        xdg.mimeApps.defaultApplications = setMimeTypes "org.gnome.Evince.desktop" [
          "application/pdf"
        ];

        home.packages = [
          pkgs.unstable.evince
        ];

        dconf.settings = {
          "org/gnome/evince/default" = {
            "show-sidebar" = true;
          };
        };
      };
    };
}
