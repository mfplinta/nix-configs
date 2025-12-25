{
  hmModule =
    { config, pkgs, lib, setMimeTypes, ... }:
    let
      inherit (lib) mkIf mkEnableOption;
      cfg = config.cfg.programs.qbittorrent;
    in
    {
      options.cfg.programs.qbittorrent = {
        enable = mkEnableOption "qbittorrent";
      };

      config = mkIf cfg.enable {
        xdg.mimeApps.defaultApplications = setMimeTypes "org.qbittorrent.qBittorrent.desktop" [
          "application/x-bittorrent"
          "x-scheme-handler/magnet"
        ];

        home.packages = [
          pkgs.qbittorrent
        ];
      };
    };
}