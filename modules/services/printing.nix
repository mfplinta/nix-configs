{
  sysModule =
    { pkgs, lib, config, ... }:
    let
      inherit (lib) mkIf mkEnableOption;
      cfg = config.cfg.programs.brave;
    in
    {
      options.cfg.services.printing = {
        enable = mkEnableOption "printing";
      };

      config = mkIf cfg.enable {
        services.printing.enable = true;
        services.printing.drivers = [ pkgs.cups-brother-hll3290cdw ];
        hardware.sane = {
          enable = true;
          disabledDefaultBackends = [ "v4l" ];
          brscan5.enable = true;
          brscan5.netDevices."Home" = {
            model = "HL-L3290CDW";
            nodename = "BRW900F0CD8426B";
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
