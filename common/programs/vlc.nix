{
  hmModule =
    {
      pkgs,
      wrapper-manager,
      setMimeTypes,
      ...
    }:
    {
      xdg.mimeApps.defaultApplications = setMimeTypes "vlc.desktop" [
        "video/mp4"
        "video/mpeg"
        "video/quicktime"
        "video/x-m4v"
        "video/x-matroska"
        "video/x-ms-wmv"
        "video/x-msvideo"
        "video/webm"
      ];

      xdg.configFile."vlc/vlcrc".source = (pkgs.formats.ini { }).generate "vlcrc" {
        qt."qt-recentplay" = 0;
        qt."qt-privacy-ask" = 0;
        core."metadata-network-access" = 0;
        core."loop" = 1;
        medialib."save-recentplay" = 0;
      };

      home.packages = [
        (wrapper-manager.lib.wrapWith pkgs {
          basePackage = pkgs.vlc;
          env.DISPLAY.value = null;
        })
      ];
    };

  sysModule =
    { ... }:
    {
      networking.firewall.allowedTCPPorts = [ 8010 ]; # Chromecast support
    };
}
