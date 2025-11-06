{
  hmModule =
    { pkgs, setMimeTypes, ... }:
    {
      xdg.mimeApps.defaultApplications = setMimeTypes "org.gnome.Evince.desktop" [
        "application/pdf"
      ];

      home.packages = [
        pkgs.unstable.evince
      ];

      dconf.settings = {
        "org/gnome/evince/default" = {
          "show-sidebar" = true;
        };
      };
    };
}
