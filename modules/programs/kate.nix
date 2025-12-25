{
  hmModule =
    { config, pkgs, lib, setMimeTypes, ... }:
    let
      inherit (lib) mkIf mkEnableOption;
      cfg = config.cfg.programs.kate;
    in
    {
      options.cfg.programs.kate = {
        enable = mkEnableOption "kate";
      };

      config = mkIf cfg.enable {
        xdg.mimeApps.defaultApplications = setMimeTypes "org.kde.kate.desktop" [
          "application/octet-stream"
          "text/plain"
        ];

        xdg.configFile."kate/lspclient/settings.json".source =
          (pkgs.formats.json { }).generate "kate-lspclient-settings"
            {
              servers.nix = {
                command = [ (lib.getExe pkgs.nixd) ];
                url = "https://github.com/nix-community/nixd";
              };
            };

        cfg.kdeglobals = {
          lspclient.InlayHints = true;
        };

        home.packages = [
          pkgs.kdePackages.kate
        ];
      };
    };
}