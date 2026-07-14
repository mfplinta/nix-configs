{
  hmModule =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib)
        mkIf
        mkEnableOption
        mkOption
        types
        ;
      cfg = config.cfg.programs.hyprlock;

      idleInhibitWarning = pkgs.writeShellApplication {
        name = "hyprlock-idle-inhibit-warning";
        runtimeInputs = [
          pkgs.hyprland
          pkgs.jq
          pkgs.systemd
        ];
        text = ''
          warning=

          if hyprctl clients -j 2>/dev/null | jq -e 'any(.[]; .inhibitingIdle == true)' >/dev/null 2>&1; then
            warning="WARNING: sleep is blocked"
          fi

          blocked="$(busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager BlockInhibited 2>/dev/null || true)"
          blocked="''${blocked#s \"}"
          blocked="''${blocked%\"}"

          case ":$blocked:" in
            *:idle:*|*:sleep:*)
              if [ -n "$warning" ]; then
                warning="$warning; idle inhibit is active"
              else
                warning="WARNING: idle inhibit is active"
              fi
              ;;
          esac

          if [ -n "$warning" ]; then
            printf "<span foreground='#ffcc66'><b>%s</b></span>\n" "$warning"
          fi
        '';
      };

      capsLockWarning = pkgs.writeShellApplication {
        name = "hyprlock-caps-lock-warning";
        runtimeInputs = [
          pkgs.hyprland
          pkgs.jq
        ];
        text = ''
          if hyprctl devices -j 2>/dev/null | jq -e 'any(.keyboards[]?; .capsLock == true)' >/dev/null 2>&1; then
            printf "<span foreground='#ff6633'><b>CAPS LOCK is active</b></span>\n"
          fi
        '';
      };
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
                capslock_color = "rgba(ffcc66ee) rgba(ff6633ee) 40deg";
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

            label = [
              {
                monitor = cfg.monitor;
                text = "cmd[update:2000] ${idleInhibitWarning}/bin/hyprlock-idle-inhibit-warning";
                color = "rgba(255, 204, 102, 1.0)";
                font_size = 18;
                font_family = "$font";
                text_align = "center";

                position = "0, 100";
                halign = "center";
                valign = "bottom";
              }
              {
                monitor = cfg.monitor;
                text = "cmd[update:500] ${capsLockWarning}/bin/hyprlock-caps-lock-warning";
                color = "rgba(255, 102, 51, 1.0)";
                font_size = 18;
                font_family = "$font";
                text_align = "center";

                position = "0, 140";
                halign = "center";
                valign = "bottom";
              }
            ];
          };
        };
      };
    };
}
