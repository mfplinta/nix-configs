{
  hmModule =
    { pkgs, hmImport, ... }:
    {
      imports = [
        (hmImport ./../programs/mpv.nix)
        (hmImport ./../programs/nomacs.nix)
      ];

      home.packages = with pkgs; [
        # Media
        nixpkgs-old.stremio
        handbrake
        darktable
        kdePackages.kdenlive
      ];
    };
}
