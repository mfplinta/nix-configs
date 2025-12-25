{
  hmModule =
    { config, pkgs, lib, setMimeTypes, ... }:
    let
      inherit (lib) mkIf mkEnableOption;
      cfg = config.cfg.programs.imhex;
    in
    {
      options.cfg.programs.imhex = {
        enable = mkEnableOption "imhex";
      };

      config = mkIf cfg.enable {
        xdg.mimeApps.defaultApplications = setMimeTypes "imhex.desktop" [
          "application/octet-stream"
        ];

        home.packages = [
          pkgs.imhex
        ];
      };
    };
}