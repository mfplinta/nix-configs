# Source: https://gitlab.com/fazzi/nixohess/-/blob/main/modules/services/nvidia_oc.nix?ref_type=heads
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
        mkEnableOption
        mkOption
        types
        mkIf
        getExe
        optionalString
        ;
      cfg = config.services.nvidia_oc;
    in
    {
      options.services.nvidia_oc = {
        enable = mkEnableOption "nvidia_oc";
        maxClock = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "Changes the max clock passed into nvidia_oc.";
        };
        coreOffset = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "Changes the core offset passed into nvidia_oc.";
        };
        memOffset = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "Changes the memory offset passed into nvidia_oc.";
        };
        powerLimit = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "Changes the power limit passed into nvidia_oc";
        };
      };

      config = mkIf cfg.enable {
        systemd.services.nvidia_oc = {
          description = "Nvidia overclocking / undervolting";
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            ExecStart = ''
              ${getExe pkgs.nvidia_oc} set --index 0 \
              ${optionalString (cfg.maxClock != null) "--min-clock 0 --max-clock ${toString cfg.maxClock}"} \
              ${optionalString (cfg.coreOffset != null) "--freq-offset ${toString cfg.coreOffset}"} \
              ${optionalString (cfg.memOffset != null) "--mem-offset ${toString (cfg.memOffset * 2)}"} \
              ${optionalString (cfg.powerLimit != null) "--power-limit ${toString (cfg.powerLimit * 1000)}"}
            '';
          };
        };
      };
    };
}
