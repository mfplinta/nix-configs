{
  hmModule =
    { lib, pkgs, ... }:
    {
      home.packages = with pkgs; [
        onlyoffice-desktopeditors
      ];

      home.activation.copyOfficeFonts = lib.hm.dag.entryAfter ["writeBoundary"] ''
        rm -rf ~/.local/share/fonts
        mkdir -p ~/.local/share/fonts
        cp ${pkgs.corefonts}/share/fonts/truetype/* ~/.local/share/fonts/
        cp ${pkgs.vista-fonts}/share/fonts/truetype/* ~/.local/share/fonts/
        chmod -R 755 ~/.local/share/fonts
      '';
    };
}
