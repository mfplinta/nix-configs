{
  sysModule =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      inherit (lib) mkIf mkEnableOption;
      cfg = config.cfg.services.printing;
      brscan5PackageOverrides = final: prev: {
        brscan5 = prev.brscan5.overrideAttrs (old: {
          postFixup = (old.postFixup or "") + ''
            for file in $out/opt/brother/scanner/brscan5/*.so.*; do
              if ! test -L "$file"; then
                patchelf --set-rpath "$(patchelf --print-rpath "$file"):"'$ORIGIN' "$file"
              fi
            done
          '';
        });
      };
    in
    {
      options.cfg.services.printing = {
        enable = mkEnableOption "printing";
      };

      config = mkIf cfg.enable {
        nixpkgs.overlays = [ brscan5PackageOverrides ];
        services.printing.enable = true;
        services.printing.drivers = [ pkgs.cups-brother-hll3290cdw ];
        hardware.sane = {
          enable = true;
          backends-package = pkgs.sane-backends-runtime-path;
          disabledDefaultBackends = [ "v4l" ];
          brscan5.enable = true;
          brscan5.netDevices."Home" = {
            model = "HL-L3290CDW";
            #nodename = "BRW900F0CD8426B";
            ip = "10.0.1.84";
          };
        };
        hardware.printers = {
          ensurePrinters = [
            {
              name = "Brother_HL-L3290CDW";
              location = "Home";
              deviceUri = "http://brw900f0cd8426b.arpa/binary_p1";
              model = "brother_hll3290cdw_printer_en.ppd";
              ppdOptions = {
                PageSize = "Paper";
              };
            }
          ];
          ensureDefaultPrinter = "Brother_HL-L3290CDW";
        };
      };
    };
}
