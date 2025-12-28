{
  hmModule =
    {
      config,
      pkgs,
      lib,
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
