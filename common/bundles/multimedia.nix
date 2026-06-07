{
  hmModule =
    { pkgs, ... }:
    {
      cfg.programs.mpv.enable = true;
      cfg.programs.nomacs.enable = true;

      home.packages = with pkgs; [
        # Media
        stremio-linux-shell
        handbrake
        darktable
        kdePackages.kdenlive
        audacity
      ];
    };
}
