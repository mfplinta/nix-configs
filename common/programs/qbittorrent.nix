{
  hmModule =
    { pkgs, setMimeTypes, ... }:
    {
      xdg.mimeApps.defaultApplications = setMimeTypes "org.qbittorrent.qBittorrent.desktop" [
        "application/x-bittorrent"
        "x-scheme-handler/magnet"
      ];

      home.packages = [
        pkgs.qbittorrent
      ];
    };
}
