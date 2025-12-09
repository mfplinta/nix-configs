{
  hmModule =
    { pkgs, hmImport, ... }:
    {
      imports = [
        (hmImport ./../programs/veracrypt.nix)
        (hmImport ./../programs/imhex.nix)
      ];

      home.packages = with pkgs; [
        # Utilities
        qalculate-gtk
        font-manager
        unstable.yt-dlp
        qdirstat
      ];
    };
}
