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
      cfg = config.cfg.programs.onlyoffice;
    in
    {
      options.cfg.programs.onlyoffice = {
        enable = mkEnableOption "onlyoffice";
      };

      config = mkIf cfg.enable {
        home.packages = with pkgs; [
          onlyoffice-desktopeditors
          corefonts
          vista-fonts
        ];

        xdg.mimeApps.defaultApplications = setMimeTypes "onlyoffice-desktopeditors.desktop" [
          "application/vnd.ms-excel"
          "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
          "application/msword"
          "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
          "application/vnd.ms-powerpoint"
          "application/vnd.openxmlformats-officedocument.presentationml.presentation"
          "application/vnd.oasis.opendocument.presentation"
          "application/vnd.oasis.opendocument.spreadsheet"
          "application/vnd.oasis.opendocument.text"
        ];

        home.activation.copyOfficeFonts = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          rm -rf ~/.local/share/fonts
          mkdir -p ~/.local/share/fonts
          cp -Lr ${config.xdg.stateHome}/home-manager/gcroots/current-home/home-path/share/fonts/* \
            ~/.local/share/fonts/
          chmod -R 755 ~/.local/share/fonts
        '';
      };
    };
}
