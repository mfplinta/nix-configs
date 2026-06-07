{
  hmModule =
    { pkgs, ... }:
    {
      cfg.programs.qbittorrent.enable = true;
      home.packages = with pkgs; [
        # Internet
        unstable.anydesk
        filezilla
      ];
    };

  sysModule =
    { ... }:
    {
      cfg.programs.brave.enable = true;
      cfg.programs.localsend.enable = true;
    };
}
