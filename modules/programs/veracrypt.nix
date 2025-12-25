{
  hmModule =
    { config, pkgs, lib, setMimeTypes, ... }:
    let
      inherit (lib) mkIf mkEnableOption;
      cfg = config.cfg.programs.veracrypt;
    in
    {
      options.cfg.programs.veracrypt = {
        enable = mkEnableOption "veracrypt";
      };

      config = mkIf cfg.enable {
        xdg.mimeApps.defaultApplications = setMimeTypes "veracrypt.desktop" [
          "application/octet-stream"
        ];

        home.packages = [
          pkgs.veracrypt
        ];
      };
    };
}