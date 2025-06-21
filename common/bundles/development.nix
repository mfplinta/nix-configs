{
  hmModule =
    { pkgs, hmImport, ... }:
    {
      imports = [
        (hmImport ./../programs/kate.nix)
        (hmImport ./../programs/vscode.nix)
      ];

      home.packages = with pkgs; [
        jetbrains.pycharm-professional
        inkscape
      ];
    };
}
