{
  hmModule =
    { pkgs, hmImport, ... }:
    {
      imports = [
        (hmImport ./../programs/brave.nix)
        (hmImport ./../programs/qbittorrent.nix)
      ];
      home.packages = with pkgs; [
        # Internet
        localsend
        anydesk
        filezilla
      ];
    };

    sysModule =
    { sysImport, ... }:
    {
      imports = [
        (sysImport ./../programs/brave.nix)
      ];
    };
}
