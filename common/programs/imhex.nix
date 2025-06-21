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
                value = [ "imhex.desktop" ];
              }) types
            );
        in
        mkEntries [
          "application/octet-stream"
        ];

      home.packages = [
        pkgs.imhex
      ];
    };
}
