{
  hmModule =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      inherit (builtins) isAttrs isList;
      inherit (lib)
        getExe
        mkOption
        range
        types
        ;

      mod = "SUPER";
      playerctl = getExe pkgs.playerctl;
      brillo = getExe pkgs.brillo;
      wofi-emoji = getExe pkgs.wofi-emoji;
      wofi-power-menu = getExe pkgs.wofi-power-menu;
      galaxy-buds-client = getExe pkgs.galaxy-buds-client;
      kwallet = "${pkgs.kdePackages.kwallet}/bin/kwalletd6";
      flameshot = getExe (pkgs.unstable.flameshot.override { enableWlrSupport = true; });
      wl-copy = "${pkgs.wl-clipboard}/bin/wl-copy";
      wl-paste = "${pkgs.wl-clipboard}/bin/wl-paste";
      wtype = getExe pkgs.wtype;
      cliphist = getExe pkgs.cliphist;
      toggle-scale = getExe pkgs.myScripts.toggle-scale;
      shortcut-help = "${getExe pkgs.myScripts.shortcut-help} --config ${shortcutHelpConfig} --global-help ${shortcutHelpGlobal}";
      wofi-drun = "uwsm app -- $(wofi --show drun --define=drun-print_desktop_file=true -i | sed 's/\.desktop /.desktop:/')";
      cmdHelp = ''
        \U2756 + E -- Show emoji picker
        \U2756 + X -- Show power menu
        \U2756 + F1 -- Show application launcher
        \U2756 + C -- Paste clipboard history
        \U2756\U21E7 + C -- Clear clipboard history
        \U2756 + S -- Toggle scale
        \U2756 + L -- Lock session
      '';
      shortcutHelpGlobal = pkgs.writeText "hyprland-global-shortcuts" cmdHelp;
      shortcutHelpConfig = pkgs.writeText "shortcut-help-config.json" (
        builtins.toJSON {
          rules = if config.cfg.shortcutHelp.enable then config.cfg.shortcutHelp.rules else { };
        }
      );

      mergeHyprland =
        left: right:
        lib.zipAttrsWith
          (
            _: values:
            let
              kept = builtins.filter (value: value != null) values;
            in
            if kept == [ ] then
              null
            else if builtins.all isList kept then
              lib.concatLists kept
            else if builtins.all isAttrs kept then
              builtins.foldl' mergeHyprland { } kept
            else
              lib.last kept
          )
          [
            left
            right
          ];

      baseSettings = {
        exec-once = [
          "uwsm app -- ${galaxy-buds-client} /StartMinimized"
          "uwsm app -- ${wl-paste} --type text --watch ${cliphist} store"
          "uwsm app -- ${wl-paste} --type image --watch ${cliphist} store"
          "uwsm app -- ${kwallet}"
        ];
        windowrule =
          let
            floatInCursorMatcher = "match:title ^(Picture in picture|Syncthing Tray|Bitwarden)";
          in
          [
            "match:class ^$,match:title ^$,match:xwayland 1,match:float 1,match:fullscreen 0,match:pin 0,no_initial_focus 1"

            "${floatInCursorMatcher},float 1"
            "${floatInCursorMatcher},pin 1"
            "${floatInCursorMatcher},no_anim 1"
            "${floatInCursorMatcher},move onscreen cursor -50% -50%"
            "${floatInCursorMatcher},opaque 1"
            "${floatInCursorMatcher},border_size 0"

            "match:title (flameshot),pin 1"
            "match:title (flameshot),float 1"
            "match:title (flameshot),no_anim 1"
            "match:title (flameshot),move 0 0"

            "match:class (ONLYOFFICE),match:float 1,no_anim 1"
            "match:class (ONLYOFFICE),match:float 1,border_size 0"
            "match:class (DesktopEditors),center 1"
            "match:class (DesktopEditors),pin 1"

            "match:title ^(Picture in picture),keep_aspect_ratio 1"
          ];
        bind = [
          "${mod}, Q, killactive"
          "${mod}, L, exec, loginctl lock-session"
          "${mod}, M, exec, uwsm stop"
          "${mod}, E, exec, uwsm app -- ${wofi-emoji}"
          "${mod}, X, exec, uwsm app -- ${wofi-power-menu}"
          "${mod}, Return, exec, uwsm app -- kitty --single-instance --listen-on ${pkgs.lib.escapeShellArg "unix:@shortcut-help-kitty"}"
          "${mod}, F1, exec, ${wofi-drun}"
          "${mod}, XF86AudioMute, exec, ${wofi-drun}"
          "${mod}, XF86Back, exec, ${wofi-drun}"
          ",Print, exec, uwsm app -- ${flameshot} gui --raw | ${wl-copy}"
          "${mod}, C, exec, ${cliphist} list | uwsm app -- wofi -S dmenu | ${cliphist} decode | ${wtype} -"
          "${mod}, S, exec, hyprctl notify -1 2000 0 \"Scale: $(${toggle-scale})x\""
          "${mod}_SHIFT, C, exec, ${cliphist} wipe && ${wl-copy} --clear && hyprctl notify -1 2000 0 'Clipboard was cleared'"
          "${mod}, Grave, exec, hyprctl notify -1 5000 0 \"$(${shortcut-help})\""
          "${mod}, mouse_down, workspace, e+1"
          "${mod}, mouse_up, workspace, e-1"
        ]
        ++ map (x: "${mod}, ${toString x}, workspace, ${toString x}") (range 1 9)
        ++ map (x: "${mod} SHIFT, ${toString x}, movetoworkspace, ${toString x}") (range 1 9);
        bindm = [
          "${mod}, mouse:272, movewindow"
          "${mod}, mouse:273, resizewindow"
          "ALT, mouse:272, resizewindow"
        ];
        bindel = [
          ", XF86AudioRaiseVolume, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+ && pw-play ${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/audio-volume-change.oga"
          ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- && pw-play ${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/audio-volume-change.oga"
          ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
          ", XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
          ", XF86MonBrightnessUp, exec, ${brillo} -e -A 5"
          ", XF86MonBrightnessDown, exec, ${brillo} -e -U 5"
        ];
        bindl = [
          ", XF86AudioNext, exec, ${playerctl} next"
          ", XF86AudioPause, exec, ${playerctl} play-pause"
          ", XF86AudioPlay, exec, ${playerctl} play-pause"
          ", XF86AudioPrev, exec, ${playerctl} previous"
        ];
        input = {
          kb_layout = "us,us";
          kb_variant = ",intl";
          kb_options = "grp:win_space_toggle";
        };
        general = {
          gaps_in = 5;
          gaps_out = 5;
          border_size = 2;
          "col.active_border" = "rgba(33ccffee) rgba(00ff99ee) 45deg";
          "col.inactive_border" = "rgba(595959aa)";
        };
        misc = {
          "force_default_wallpaper" = 1;
          "disable_hyprland_logo" = true;
          "disable_splash_rendering" = true;
          "enable_anr_dialog" = false;
          "disable_watchdog_warning" = true;
        };
        ecosystem = {
          "no_update_news" = true;
          "no_donation_nag" = true;
          "enforce_permissions" = false;
        };
      };

      settings = mergeHyprland baseSettings config.cfg.hyprland;
      settingsJson = pkgs.writeText "hyprland-settings.json" (builtins.toJSON settings);
      lua = pkgs.lua5_4.withPackages (ps: [ ps.dkjson ]);
      generatedConfig = pkgs.runCommand "hyprland-generated.lua" { nativeBuildInputs = [ lua ]; } ''
        lua ${./generator.lua} ${settingsJson} > $out
      '';
    in
    {
      options.cfg.hyprland = lib.mkOption {
        type = with lib.types; attrsOf anything;
        default = { };
        description = "Hyprland target-specific configuration merged into Lua-generated config.";
      };

      options.cfg.shortcutHelp = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Whether Super+Grave includes focused-application shortcut help.";
        };

        rules = mkOption {
          type = types.attrsOf (
            types.submodule (
              { name, ... }:
              {
                options = {
                  title = mkOption {
                    type = types.str;
                    default = name;
                    description = "Section title shown for this shortcut group.";
                  };

                  match = {
                    executables = mkOption {
                      type = types.listOf types.str;
                      default = [ ];
                      description = "Focused application executable basenames that should match this rule.";
                    };

                    classes = mkOption {
                      type = types.listOf types.str;
                      default = [ ];
                      description = "Focused Hyprland window classes that should match this rule.";
                    };

                    titles = mkOption {
                      type = types.listOf types.str;
                      default = [ ];
                      description = "Focused Hyprland window titles that should match this rule exactly.";
                    };

                    terminalForegroundExecutables = mkOption {
                      type = types.listOf types.str;
                      default = [ ];
                      description = "Foreground executable basenames in the active terminal window that should match this rule.";
                    };
                  };

                  shortcuts = mkOption {
                    type = types.listOf types.str;
                    default = [ ];
                    example = [
                      "Ctrl+W -- Close tab"
                      "Ctrl+P -- Print"
                    ];
                    description = "Shortcut lines shown when the rule matches.";
                  };
                };
              }
            )
          );
          default = { };
          example = {
            brave = {
              title = "Brave";
              match.executables = [ "brave" ];
              shortcuts = [
                "Ctrl+W -- Close tab"
                "Ctrl+P -- Print"
              ];
            };
            tmux = {
              title = "tmux";
              match.terminalForegroundExecutables = [ "tmux" ];
              shortcuts = [
                "Ctrl+B, C -- Create window"
                "Ctrl+B, N -- Move to next window"
              ];
            };
          };
          description = "Manually authored shortcut help rules for the focused application.";
        };
      };

      config = {
        wayland.windowManager.hyprland = {
          enable = true;
          configType = "lua";
          settings = { };
          extraConfig = ''
            dofile("${generatedConfig}")
          '';

          package = null;
          portalPackage = null;
          systemd.variables = [ "--all" ];
        };

        xdg.configFile."uwsm/env-hyprland".text = ''
          export HYPRLAND_CONFIG="${config.xdg.configHome}/hypr/hyprland.lua"
        '';

        home.activation.removeAutogeneratedHyprlandConf = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          hyprland_conf="${config.xdg.configHome}/hypr/hyprland.conf"
          if [ -f "$hyprland_conf" ] && grep -q "This config is a STUB" "$hyprland_conf"; then
            rm "$hyprland_conf"
          fi
        '';
      };
    };
}
