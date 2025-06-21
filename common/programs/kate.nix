{
  hmModule =
    { pkgs, setMimeTypes, ... }:
    {
      xdg.mimeApps.defaultApplications = setMimeTypes "org.kde.kate.desktop" [
        "application/octet-stream"
        "text/plain"
      ];

      home.packages = [
        pkgs.kdePackages.kate
      ];
    };
}
