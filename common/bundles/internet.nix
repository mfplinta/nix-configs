{
  hmModule =
    { pkgs, hmImport, ... }:
    {
      imports = [
        (hmImport ./../programs/brave.nix)
        (hmImport ./../programs/qbittorrent.nix)
        (hmImport ./../programs/localsend.nix)
      ];
      home.packages = with pkgs; [
        # Internet
        anydesk
        filezilla
      ];
    };

    sysModule =
    { sysImport, ... }:
    {
      imports = [
        (sysImport ./../programs/brave.nix)
        (sysImport ./../programs/localsend.nix)
      ];
    };
}
