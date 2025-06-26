{
  hmModule =
    { pkgs, setMimeTypes, ... }:
    with pkgs;
    {
      xdg.mimeApps.defaultApplications = setMimeTypes "org.kde.kate.desktop" [
        "application/octet-stream"
        "text/plain"
      ];

      xdg.configFile."kate/lspclient/settings.json".source =
        (pkgs.formats.json { }).generate "kate-lspclient-settings"
          {
            servers.nix = {
              command = [ (lib.getExe nixd) ];
              url = "https://github.com/nix-community/nixd";
            };
          };

      myCfg.kdeglobals = {
        lspclient.InlayHints = true;
      };

      home.packages = [
        pkgs.kdePackages.kate
      ];
    };
}
