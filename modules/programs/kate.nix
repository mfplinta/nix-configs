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
      cfg = config.cfg.programs.kate;
    in
    {
      options.cfg.programs.kate = {
        enable = mkEnableOption "kate";
      };

      config = mkIf cfg.enable {
        xdg.mimeApps.defaultApplications = setMimeTypes "org.kde.kate.desktop" [
          "application/json"
          "application/octet-stream"
          "application/xml"
          "text/plain"
        ];

        xdg.configFile."kate/lspclient/settings.json".source =
          (pkgs.formats.json { }).generate "kate-lspclient-settings"
            {
              servers = {
                nix = {
                  command = [ (lib.getExe pkgs.nixd) ];
                  url = "https://github.com/nix-community/nixd";
                };
                json = {
                  command = [
                    (lib.getExe pkgs.vscode-json-languageserver)
                    "--stdio"
                  ];
                  url = "https://github.com/microsoft/vscode/tree/main/extensions/json-language-features/server";
                };
                xml = {
                  command = [ (lib.getExe pkgs.lemminx) ];
                  url = "https://github.com/redhat-developer/vscode-xml#lemminx-binary";
                };
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
