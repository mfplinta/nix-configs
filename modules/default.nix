{
  sysModule =
    { sysImport, ... }:
    {
      imports = [
        (sysImport ./programs/brave.nix)
        (sysImport ./programs/fish.nix)
        (sysImport ./programs/localsend.nix)
        (sysImport ./programs/vim)
        (sysImport ./programs/vlc.nix)

        (sysImport ./services/displayManager/sddm-weston.nix)
        (sysImport ./services/samba/client.nix)
        (sysImport ./services/samba/host.nix)
        (sysImport ./services/caddy.nix)
        (sysImport ./services/crowdsec.nix)
        (sysImport ./services/django-website.nix)
        (sysImport ./services/nextcloud.nix)
        (sysImport ./services/nvidia_oc.nix)
        (sysImport ./services/printing.nix)
        (sysImport ./services/vmagent.nix)

        (sysImport ./virtualisation/distrobox.nix)
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
        (hmImport ./programs/hyprlock.nix)
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
        (hmImport ./programs/vlc.nix)
        (hmImport ./programs/vscode.nix)
        (hmImport ./programs/waybar)

        (hmImport ./services/containerized/jdownloader2.nix)
        (hmImport ./services/hypridle.nix)

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
