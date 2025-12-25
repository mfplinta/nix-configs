{
  hmModule =
    { pkgs, ... }:
    {
      cfg.programs.veracrypt.enable = true;
      cfg.programs.imhex.enable = true;
      cfg.programs.gparted.enable = true;

      home.packages = with pkgs; [
        # Utilities
        qalculate-gtk
        font-manager
        unstable.yt-dlp
        qdirstat
      ];
    };
}
