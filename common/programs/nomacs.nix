{
  hmModule =
    { pkgs, setMimeTypes, ... }:
    {
      xdg.mimeApps.defaultApplications = setMimeTypes "org.nomacs.ImageLounge.desktop" [
        "image/bmp"
        "image/gif"
        "image/jpeg"
        "image/png"
        "image/vnd.adobe.photoshop"
        "image/tiff"
        "image/webp"
      ];

      home.packages = [
        pkgs.nomacs
      ];
    };
}
