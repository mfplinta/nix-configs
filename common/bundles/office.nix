{
  hmModule =
    { pkgs, lib, ... }:
    let
      simpleScanWithRuntimeSane = pkgs.simple-scan.overrideAttrs (old: {
        buildInputs = map (
          pkg: if lib.getName pkg == "sane-backends" then pkgs.sane-backends-runtime-path else pkg
        ) old.buildInputs;
      });
    in
    {
      cfg.programs.calibre.enable = true;
      cfg.programs.okular.enable = true;
      cfg.programs.onlyoffice.enable = true;

      home.packages = with pkgs; [
        # Office
        simpleScanWithRuntimeSane
      ];
    };
}
