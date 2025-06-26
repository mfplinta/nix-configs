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
        stremio
        handbrake
        darktable
      ];
    };
}
