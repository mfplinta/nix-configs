{
  hmModule =
    { pkgs, hmImport, ... }:
    {
      imports = [
        (hmImport ./../programs/okular.nix)
      ];

      home.packages = with pkgs; [
        # Office
        simple-scan
        onlyoffice-desktopeditors
      ];
    };
}
