{
  hmModule =
    { pkgs, hmImport, ... }:
    {
      imports = [
        (hmImport ./../programs/okular.nix)
        (hmImport ./../programs/onlyoffice.nix)
      ];

      home.packages = with pkgs; [
        # Office
        simple-scan
      ];
    };
}
