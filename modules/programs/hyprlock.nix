{
  hmModule =
    {
      config,
      lib,
      ...
    }:
    let
      inherit (lib) mkIf mkEnableOption mkOption types;
      cfg = config.cfg.programs.hyprlock;
    in
    {
      options.cfg.programs.hyprlock = {
        enable = mkEnableOption "hyprlock";
        monitor = mkOption {
          type = types.str;
        };
      };

      config = mkIf cfg.enable {
        programs.hyprlock = {
          enable = true;
          settings = {
            "$font" = "Monospace";
            general = {
              hide_cursor = true;
            };

            background = [
              {
                monitor = "";
                path = "screenshot";
                blur_passes = 6;
              }
            ];

            input-field = [
              {
                monitor = cfg.monitor;
                size = "20%, 5%";
                outline_thickness = 3;

                inner_color = "rgba(0, 0, 0, 0.0)";
                outer_color = "rgba(33ccffee) rgba(00ff99ee) 45deg";
                check_color = "rgba(00ff99ee) rgba(ff6633ee) 120deg";
                fail_color = "rgba(ff6633ee) rgba(ff0066ee) 40deg";
                font_color = "rgb(143, 143, 143)";

                fade_on_empty = false;
                rounding = 15;
                dots_spacing = "0.3";

                font_family = "$font";
                placeholder_text = "Input password...";
                fail_text = "$PAMFAIL";

                position = "0, -80";
                halign = "center";
                valign = "center";
              }
            ];
          };
        };
      };
    };
}
