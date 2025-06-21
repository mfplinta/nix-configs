{
  hmModule =
    { pkgs, setMimeTypes, ... }:
    {
      xdg.mimeApps.defaultApplications = setMimeTypes "imhex.desktop" [
        "application/octet-stream"
      ];

      home.packages = [
        pkgs.imhex
      ];
    };
}
