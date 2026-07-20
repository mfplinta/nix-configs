{
  hmModule =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      inherit (lib)
        getExe
        mkOption
        range
        types
        ;

      luaInline = lib.generators.mkLuaInline;
      toLua = lib.generators.toLua { };

      playerctl = getExe pkgs.playerctl;
      brillo = getExe pkgs.brillo;
      wofi-emoji = getExe pkgs.wofi-emoji;
      wofi-power-menu = getExe pkgs.wofi-power-menu;
      galaxy-buds-client = getExe pkgs.galaxy-buds-client;
      kwallet = "${pkgs.kdePackages.kwallet}/bin/kwalletd6";
      flameshot = getExe config.services.flameshot.package;
      wl-copy = "${pkgs.wl-clipboard}/bin/wl-copy";
      wl-paste = "${pkgs.wl-clipboard}/bin/wl-paste";
      wtype = getExe pkgs.wtype;
      cliphist = getExe pkgs.cliphist;
      cliphistRuntime = ''${cliphist} -db-path "$XDG_RUNTIME_DIR/cliphist.db"'';
      toggle-scale = getExe pkgs.myScripts.toggle-scale;
      shortcut-help = "${getExe pkgs.myScripts.shortcut-help} --config ${shortcutHelpConfig} --global-help ${shortcutHelpGlobal}";
      wofi-drun = "uwsm app -- $(wofi --show drun --define=drun-print_desktop_file=true -i | sed 's/[.]desktop /.desktop:/')";

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

      bind = key: action: flags: {
        _args = [
          key
          action
        ]
        ++ lib.optional (flags != { }) flags;
      };
      exec = command: luaInline "hl.dsp.exec_cmd(${toLua command})";
      focusWorkspace = workspace: luaInline "hl.dsp.focus({ workspace = ${toLua workspace} })";
      moveToWorkspace = workspace: luaInline "hl.dsp.window.move({ workspace = ${toLua workspace} })";

      baseSettings = {
        config = lib.mapAttrsRecursive (_: lib.mkDefault) {
          ecosystem = {
            enforce_permissions = false;
            no_donation_nag = true;
            no_update_news = true;
          };
          general = {
            gaps_in = 5;
            gaps_out = 5;
            border_size = 2;
            col = {
              active_border = {
                colors = [
                  "rgba(33ccffee)"
                  "rgba(00ff99ee)"
                ];
                angle = 45;
              };
              inactive_border = "rgba(595959aa)";
            };
          };
          input = {
            kb_layout = "us,us";
            kb_variant = ",intl";
            kb_options = "grp:win_space_toggle";
          };
          misc = {
            force_default_wallpaper = 1;
            disable_hyprland_logo = true;
            disable_splash_rendering = true;
            enable_anr_dialog = false;
            disable_watchdog_warning = true;
          };
        };

        window_rule = lib.mkBefore [
          {
            name = "fix-xwayland-drags";
            match = {
              class = "^$";
              title = "^$";
              xwayland = true;
              float = true;
              fullscreen = false;
              pin = false;
            };
            no_focus = true;
          }
          {
            name = "floating-tools-at-cursor";
            match.title = "^(Picture in picture|Syncthing Tray|Bitwarden)";
            float = true;
            pin = true;
            no_anim = true;
            move = "onscreen cursor -50% -50%";
            opaque = true;
            border_size = 0;
          }
          {
            name = "flameshot-overlay";
            match.title = "(flameshot)";
            pin = true;
            float = true;
            no_anim = true;
            move = "0 0";
          }
          {
            name = "onlyoffice-floating";
            match = {
              class = "(ONLYOFFICE)";
              float = true;
            };
            no_anim = true;
            border_size = 0;
          }
          {
            name = "onlyoffice-editor";
            match.class = "(DesktopEditors)";
            center = true;
            pin = true;
          }
          {
            name = "picture-in-picture-ratio";
            match.title = "^(Picture in picture)";
            keep_aspect_ratio = true;
          }
        ];

        bind = lib.mkBefore (
          [
            (bind "SUPER + Q" (luaInline "hl.dsp.window.close()") { })
            (bind "SUPER + L" (exec "loginctl lock-session") { })
            (bind "SUPER + M" (exec "uwsm stop") { })
            (bind "SUPER + E" (exec "uwsm app -- ${wofi-emoji}") { })
            (bind "SUPER + X" (exec "uwsm app -- ${wofi-power-menu}") { })
            (bind "SUPER + Return"
              (exec "uwsm app -- kitty --single-instance --listen-on unix:@shortcut-help-kitty")
              { }
            )
            (bind "SUPER + F1" (exec wofi-drun) { })
            (bind "SUPER + XF86AudioMute" (exec wofi-drun) { })
            (bind "SUPER + XF86Back" (exec wofi-drun) { })
            (bind "Print" (exec "uwsm app -- ${flameshot} gui --raw | ${wl-copy}") { })
            (bind "SUPER + C"
              (exec "${cliphistRuntime} list | uwsm app -- wofi -S dmenu | ${cliphistRuntime} decode | ${wtype} -")
              { }
            )
            (bind "SUPER + S" (exec ''hyprctl notify -1 2000 0 "Scale: $(${toggle-scale})x"'') { })
            (bind "SUPER + SHIFT + C"
              (exec "${cliphistRuntime} wipe && ${wl-copy} --clear && hyprctl notify -1 2000 0 'Clipboard was cleared'")
              { }
            )
            (bind "SUPER + Grave" (exec ''hyprctl notify -1 5000 0 "$(${shortcut-help})"'') { })
            (bind "SUPER + mouse_down" (focusWorkspace "e+1") { })
            (bind "SUPER + mouse_up" (focusWorkspace "e-1") { })
          ]
          ++ map (workspace: bind "SUPER + ${toString workspace}" (focusWorkspace (toString workspace)) { }) (
            range 1 9
          )
          ++ map (
            workspace: bind "SUPER + SHIFT + ${toString workspace}" (moveToWorkspace (toString workspace)) { }
          ) (range 1 9)
          ++ [
            (bind "SUPER + mouse:272" (luaInline "hl.dsp.window.drag()") { mouse = true; })
            (bind "SUPER + mouse:273" (luaInline "hl.dsp.window.resize()") { mouse = true; })
            (bind "ALT + mouse:272" (luaInline "hl.dsp.window.resize()") { mouse = true; })
            (bind "XF86AudioRaiseVolume"
              (exec "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+ && pw-play ${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/audio-volume-change.oga")
              {
                locked = true;
                repeating = true;
              }
            )
            (bind "XF86AudioLowerVolume"
              (exec "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- && pw-play ${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/audio-volume-change.oga")
              {
                locked = true;
                repeating = true;
              }
            )
            (bind "XF86AudioMute" (exec "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle") {
              locked = true;
              repeating = true;
            })
            (bind "XF86AudioMicMute" (exec "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle") {
              locked = true;
              repeating = true;
            })
            (bind "XF86MonBrightnessUp" (exec "${brillo} -e -A 5") {
              locked = true;
              repeating = true;
            })
            (bind "XF86MonBrightnessDown" (exec "${brillo} -e -U 5") {
              locked = true;
              repeating = true;
            })
            (bind "XF86AudioNext" (exec "${playerctl} next") { locked = true; })
            (bind "XF86AudioPause" (exec "${playerctl} play-pause") { locked = true; })
            (bind "XF86AudioPlay" (exec "${playerctl} play-pause") { locked = true; })
            (bind "XF86AudioPrev" (exec "${playerctl} previous") { locked = true; })
          ]
        );

        on = {
          _args = [
            "hyprland.start"
            (luaInline ''
              function()
                hl.exec_cmd(${toLua "uwsm app -- ${galaxy-buds-client} /StartMinimized"})
                hl.exec_cmd(${toLua "uwsm app -- ${wl-paste} --type text --watch ${cliphistRuntime} store"})
                hl.exec_cmd(${toLua "uwsm app -- ${wl-paste} --type image --watch ${cliphistRuntime} store"})
                hl.exec_cmd(${toLua "uwsm app -- ${kwallet}"})
              end
            '')
          ];
        };
      };
    in
    {
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
          settings = baseSettings;

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
