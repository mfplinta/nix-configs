{
  hmModule =
    { pkgs, ... }:
    {
      xdg.mimeApps.defaultApplications =
        let
          mkEntries =
            types:
            builtins.listToAttrs (
              map (type: {
                name = type;
                value = [ "okularApplication_pdf.desktop" ];
              }) types
            );
        in
        mkEntries [
          "application/pdf"
        ];

      home.packages = [
        pkgs.kdePackages.okular
      ];
    };
}
