{
  hmModule =
    { pkgs, ... }:
    {
      xdg.mimeApps.defaultApplications =
        let
          mkEntries =
            types:
            builtins.listToAttrs (
              map (type: {
                name = type;
                value = [ "org.qbittorrent.qBittorrent.desktop" ];
              }) types
            );
        in
        mkEntries [
          "application/x-bittorrent"
          "x-scheme-handler/magnet"
        ];

      home.packages = [
        pkgs.qbittorrent
      ];
    };
}
