{
  hmModule =
    { pkgs, ... }:
    {
      cfg.programs.calibre.enable = true;
      cfg.programs.okular.enable = true;
      cfg.programs.onlyoffice.enable = true;
      
      home.packages = with pkgs; [
        # Office
        simple-scan
      ];
    };
}
