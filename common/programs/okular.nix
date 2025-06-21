{
  hmModule =
    { pkgs, setMimeTypes, ... }:
    {
      xdg.mimeApps.defaultApplications = setMimeTypes "okularApplication_pdf.desktop" [
        "application/pdf"
      ];

      home.packages = [
        pkgs.kdePackages.okular
      ];
    };
}
