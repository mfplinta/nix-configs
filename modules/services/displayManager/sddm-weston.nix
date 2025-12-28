{
  sysModule =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      inherit (lib)
        mkIf
        mkEnableOption
        mkOption
        mapAttrsToList
        types
        ;
      cfg = config.cfg.services.displayManager.sddm-weston;

      mkWestonConfig =
        outputs:
        lib.concatStringsSep "\n" (
          mapAttrsToList (name: opt: ''
            [output]
            name=${name}
            mode=${opt.mode}
          '') outputs
        );
    in
    {
      options.cfg.services.displayManager.sddm-weston = {
        enable = mkEnableOption "sddm-weston";
        theme = mkOption {
          type = types.str;
          default = "";
          description = "SDDM theme to use.";
        };
        outputs = mkOption {
          description = "Weston output configurations for SDDM.";
          default = { };
          type = types.attrsOf (
            types.submodule {
              options = {
                mode = mkOption {
                  type = types.str;
                  example = "3840x2160@60";
                };
              };
            }
          );
        };
      };

      config = mkIf cfg.enable {
        services.displayManager = {
          enable = true;
          sddm = {
            enable = true;
            wayland.enable = true;
            theme = cfg.theme;
            package = pkgs.kdePackages.sddm;
            wayland.compositorCommand =
              let
                westonIni = pkgs.writeText "weston.ini" ''
                  [core]
                  backend=drm
                  ${mkWestonConfig cfg.outputs}
                '';
              in
              "${lib.getExe pkgs.weston} --shell=kiosk -c ${westonIni}";
          };
        };
      };
    };
}
