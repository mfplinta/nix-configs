{
  hmModule =
    { pkgs, setMimeTypes, ... }:
    {
      xdg.mimeApps.defaultApplications = setMimeTypes "veracrypt.desktop" [
        "application/octet-stream"
      ];

      home.packages = [
        pkgs.veracrypt
      ];
    };
}
