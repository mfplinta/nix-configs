{
  hmModule =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib) mkIf mkEnableOption;
      cfg = config.cfg.services.hypridle;
    in
    {
      options.cfg.services.hypridle = {
        enable = mkEnableOption "hypridle";
      };

      config = mkIf cfg.enable {
        services.hypridle = {
          enable = true;
          package = pkgs.unstable.hypridle;
          settings = {
            general = {
              before_sleep_cmd = "loginctl lock-session";
              after_sleep_cmd = "hyprctl dispatch 'hl.dsp.dpms({ action = \"enable\" })'";
              ignore_dbus_inhibit = false;
              inhibit_sleep = 3;
              lock_cmd = "pidof hyprlock || hyprlock";
            };

            listener = [
              {
                timeout = 30;
                on-timeout = "pidof hyprlock && hyprctl dispatch 'hl.dsp.dpms({ action = \"disable\" })'";
              }
              {
                timeout = 300;
                on-timeout = "loginctl lock-session";
              }
              {
                timeout = 330;
                on-timeout = "hyprctl dispatch 'hl.dsp.dpms({ action = \"disable\" })'";
              }
            ];
          };
        };
      };
    };
}
