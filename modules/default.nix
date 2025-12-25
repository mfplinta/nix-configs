{
  sysModule =
    { sysImport, ... }:
    {
      imports = [
        (sysImport ./programs/brave.nix)
        (sysImport ./programs/fish.nix)
        (sysImport ./programs/localsend.nix)
        (sysImport ./programs/vlc.nix)

        (sysImport ./services/django-website.nix)
        (sysImport ./services/nvidia_oc.nix)
        (sysImport ./services/vmagent.nix)

        (sysImport ./virtualisation/quadlet.nix)
        (sysImport ./virtualisation/libvirt.nix)
      ];
    };

  hmModule =
    { hmImport, ... }:
    {
      imports = [
        (hmImport ./programs/brave.nix)
        (hmImport ./programs/dolphin.nix)
        (hmImport ./programs/evince.nix)
        (hmImport ./programs/fish.nix)
        (hmImport ./programs/gparted.nix)
        (hmImport ./programs/imhex.nix)
        (hmImport ./programs/kate.nix)
        (hmImport ./programs/kitty.nix)
        (hmImport ./programs/localsend.nix)
        (hmImport ./programs/mpv.nix)
        (hmImport ./programs/nomacs.nix)
        (hmImport ./programs/okular.nix)
        (hmImport ./programs/onlyoffice.nix)
        (hmImport ./programs/qbittorrent.nix)
        (hmImport ./programs/veracrypt.nix)
        (hmImport ./programs/vscode.nix)
        (hmImport ./programs/vlc.nix)

        (hmImport ./services/containerized/jdownloader2.nix)

        (hmImport ./virtualisation/libvirt.nix)
      ];

      _module.args = {
        setMimeTypes =
          desktopEntry: types:
          builtins.listToAttrs (
            map (type: {
              name = type;
              value = [ desktopEntry ];
            }) types
          );
      };
    };
}
