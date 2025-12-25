{
  hmModule =
    { pkgs, ... }:
    {
      cfg.programs.mpv.enable = true;
      cfg.programs.nomacs.enable = true;

      home.packages = with pkgs; [
        # Media
        nixpkgs-old.stremio
        handbrake
        darktable
        kdePackages.kdenlive
      ];
    };
}
