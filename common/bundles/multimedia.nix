{
  hmModule =
    { pkgs, ... }:
    {
      cfg.programs.mpv.enable = true;
      cfg.programs.nomacs.enable = true;

      home.packages = with pkgs; [
        # Media
        old.stremio
        handbrake
        darktable
        kdePackages.kdenlive
      ];
    };
}
