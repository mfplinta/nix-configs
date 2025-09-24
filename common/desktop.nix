{
  hmModule =
    {
      pkgs,
      lib,
      inputs,
      config,
      hmImport,
      ...
    }:
    let
      mod = "SUPER";
    in
    {
      imports = [
        (hmImport ./programs/kitty.nix)
      ];

      options.myCfg = {
        hyprland = lib.mkOption {
          type = with lib.types; attrsOf anything;
          description = "Hyprland target-specific configuration";
        };
        hyprpanel = lib.mkOption {
          type = with lib.types; attrsOf anything;
          description = "Hyprpanel target-specific configuration";
        };
        mainMonitor = lib.mkOption {
          type = lib.types.str;
          description = "Main monitor";
        };
      };

      config = {
        myCfg.kdeglobals = {
          UiSettings."ColorScheme" = "Flat-Remix-Red-Darkest";
          Icons."Theme" = "Flat-Remix-Red-Dark";
        };

        wayland.windowManager.hyprland = {
          enable = true;

          settings =
            with builtins;
            with lib;
            let
              playerctl = getExe pkgs.playerctl;
              brillo = getExe pkgs.brillo;
              wofi-emoji = getExe pkgs.wofi-emoji;
              wofi-power-menu = getExe pkgs.wofi-power-menu;
              galaxy-buds-client = getExe pkgs.galaxy-buds-client;
              flameshot = getExe (pkgs.flameshot.override { enableWlrSupport = true; });
              wl-copy = "${pkgs.wl-clipboard}/bin/wl-copy";
              wl-paste = "${pkgs.wl-clipboard}/bin/wl-paste";
              wtype = getExe pkgs.wtype;
              cliphist = getExe pkgs.cliphist;
              toggle-scale = getExe (pkgs.myScripts.toggle-scale);
              cmdHelp = ''
                \U2756 + E -- Show emoji picker
                \U2756 + X -- Show power menu
                \U2756 + F1 -- Show application launcher
                \U2756 + C -- Paste clipboard history
                \U2756\U21E7 + C -- Clear clipboard history
                \U2756 + S -- Toggle scale
                \U2756 + L -- Lock session
              '';
            in
            lib.mkMerge [
              {
                exec-once = [
                  "uwsm app -- ${galaxy-buds-client} /StartMinimized"
                  "uwsm app -- ${wl-paste} --type text --watch ${cliphist} store"
                  "uwsm app -- ${wl-paste} --type image --watch ${cliphist} store"
                ];
                windowrule =
                  let
                    floatInCursorMatcher = "title:^(Picture in picture|Syncthing Tray|Bitwarden)";
                  in
                  [
                    "suppressevent maximize, class:.*"
                    "nofocus,class:^$,title:^$,xwayland:1,floating:1,fullscreen:0,pinned:0"

                    "float,${floatInCursorMatcher}"
                    "pin,${floatInCursorMatcher}"
                    "noanim,${floatInCursorMatcher}"
                    "move onscreen cursor -50% -50%,${floatInCursorMatcher}"
                    "opaque,${floatInCursorMatcher}"
                    "noborder,${floatInCursorMatcher}"

                    "move 0 0,class:(flameshot)"
                    "pin,class:(flameshot)"
                    "noborder,class:(flameshot)"
                    "stayfocused,class:(flameshot)"
                    "float,class:(flameshot)"
                    "opaque,class:(flameshot)"

                    "noanim,floating:1,class:(ONLYOFFICE)"
                    "noborder,floating:1,class:(ONLYOFFICE)"
                    "center 1,class:(DesktopEditors)"
                    "pin,class:(DesktopEditors)"

                    "keepaspectratio,title:^(Picture in picture)"
                  ];
                bind =
                let
                  wofi-drun = "uwsm app -- $(wofi --show drun --define=drun-print_desktop_file=true)";
                in
                  [
                    # Command binds
                    "${mod}, Q, killactive"
                    "${mod}, L, exec, loginctl lock-session"
                    "${mod}, M, exec, uwsm stop"
                    "${mod}, E, exec, uwsm app -- ${wofi-emoji}"
                    "${mod}, X, exec, uwsm app -- ${wofi-power-menu}"
                    "${mod}, Return, exec, uwsm app -- kitty"
                    "${mod}, F1, exec, ${wofi-drun}"
                    "${mod}, XF86AudioMute, exec, ${wofi-drun}"
                    "${mod}, XF86Back, exec, ${wofi-drun}"
                    ",Print, exec, uwsm app -- ${flameshot} gui --raw | ${wl-copy}"
                    "${mod}, C, exec, ${cliphist} list | uwsm app -- wofi -S dmenu | ${cliphist} decode | ${wtype} -"
                    "${mod}, S, exec, hyprctl notify -1 2000 0 \"Scale: $(${toggle-scale})x\""
                    "${mod}_SHIFT, C, exec, ${cliphist} wipe && ${wl-copy} --clear && hyprctl notify -1 2000 0 'Clipboard was cleared'"
                    "${mod}, Grave, exec, hyprctl notify -1 5000 0 \"$(echo -e \"${replaceStrings ["\n"] ["\\n"] cmdHelp}\")\""
                    # Scroll through workspaces
                    "${mod}, mouse_down, workspace, e+1"
                    "${mod}, mouse_up, workspace, e-1"
                  ]
                  ++ map (x: "${mod}, ${toString x}, workspace, ${toString x}") (range 1 9) # Switch to workspace
                  ++ map (x: "${mod} SHIFT, ${toString x}, movetoworkspace, ${toString x}") (range 1 9); # Move active window to workspace
                bindm = [
                  # Move window $mod + LMB; Resize $mod/ALT + RMB
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
                  gaps_in = lib.mkDefault 5;
                  gaps_out = lib.mkDefault 20;
                  border_size = lib.mkDefault 2;
                  "col.active_border" = "rgba(33ccffee) rgba(00ff99ee) 45deg";
                  "col.inactive_border" = "rgba(595959aa)";
                };
                misc."force_default_wallpaper" = 1;
                misc."disable_hyprland_logo" = true;
                misc."enable_anr_dialog" = false;
              }
              config.myCfg.hyprland
            ];

          package = null;
          portalPackage = null;
          systemd.variables = [ "--all" ];
        };

        programs.wofi = {
          enable = true;
          settings = {
            allow_images = true;
          };
        };

        programs.hyprpanel = {
          enable = true;

          settings = lib.mkMerge [
            {
              "theme.osd.location" = "bottom";
              "theme.osd.orientation" = "horizontal";
              "theme.osd.margins" = "7px 7px 150px 7px";
              "menus.clock.weather.enabled" = false;
              "menus.dashboard.directories.left.directory3.label" = "󰚝 BYU";
              "menus.dashboard.directories.left.directory3.command" = ''bash -c "xdg-open $HOME/Syncthing/BYU/"'';
              "bar.workspaces.show_numbered" = true;
            }
            config.myCfg.hyprpanel
          ];
        };

        xdg.configFile."hyprpanel/modules.json".source =
          (pkgs.formats.json { }).generate "hyprpanel-modules"
            {
              "custom/brightness" = {
                icon = [
                  "󰃞"
                  "󰃟"
                  "󰃠"
                ];
                label = "{percentage}%";
                tooltip = "{tooltip}";
                truncationSize = -1;
                execute = "${lib.getExe pkgs.myScripts.get-current-brightness}";
                executeOnAction = "";
                interval = 1000;
                hideOnEmpty = true;
                scrollThreshold = 1;
                actions = {
                  onLeftClick = "";
                  onRightClick = "";
                  onMiddleClick = "";
                  onScrollUp = "brillo -e -S $(($(printf '%.0f\n' $(brillo))+5))";
                  onScrollDown = "brillo -e -S $(($(printf '%.0f\n' $(brillo))-5))";
                };
              };
              "custom/ioperc" = {
                icon = [ "󰒋" ];
                label = "{percentage}%";
                tooltip = "{tooltip}";
                truncationSize = -1;
                execute = "${lib.getExe pkgs.myScripts.get-current-io-util}";
                executeOnAction = "";
                interval = 1000;
                hideOnEmpty = true;
                scrollThreshold = 1;
              };
            };

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
                monitor = config.myCfg.mainMonitor;
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

        services.hyprsunset.enable = true;
        services.hyprpolkitagent.enable = true;

        services.hyprpaper = {
          enable = true;
          settings = {
            ipc = "on";
          };
        };

        services.hypridle = {
          enable = true;
          settings = {
            general = {
              before_sleep_cmd = "loginctl lock-session";
              after_sleep_cmd = "hyprctl dispatch dpms on";
              ignore_dbus_inhibit = false;
              lock_cmd = "pidof hyprlock || hyprlock";
            };

            listener = [
              {
                timeout = 30;
                on-timeout = "pidof hyprlock && hyprctl dispatch dpms off";
                on-resume = "hyprctl dispatch dpms on";
              }
              {
                timeout = 300;
                on-timeout = "loginctl lock-session";
              }
              {
                timeout = 330;
                on-timeout = "hyprctl dispatch dpms off";
                on-resume = "hyprctl dispatch dpms on";
              }
            ];
          };
        };

        fonts.fontconfig.enable = true;
        services.network-manager-applet.enable = true;
        services.blueman-applet.enable = true;
        services.udiskie.enable = true;
        services.easyeffects.enable = true;
        services.kdeconnect = {
          enable = true;
          indicator = true;
        };

        systemd.user.services.pam_kwallet_init = {
          Unit = {
            Description = "KWallet automatic unlock";
            After = [ "graphical-session.target" ];
            ConditionEnvironment = [ "WAYLAND_DISPLAY" ];
            PartOf = [ "graphical-session.target" ];
          };

          Service = {
            Type = "oneshot";
            ExecStart = "${pkgs.kdePackages.kwallet-pam}/libexec/pam_kwallet_init";
          };

          Install = {
            WantedBy = [ "graphical-session.target" ];
          };
        };

        gtk = {
          enable = true;

          theme = {
            package = pkgs.flat-remix-gtk;
            name = "Flat-Remix-GTK-Red-Darkest";
          };

          cursorTheme = {
            package = pkgs.bibata-cursors;
            size = 32;
            name = "Bibata-Modern-Ice";
          };

          iconTheme = {
            package = pkgs.flat-remix-icon-theme;
            name = "Flat-Remix-Red-Dark";
          };
        };

        xdg.dataFile = {
          "color-schemes".source = "${pkgs.flat-remix-kde}/share/color-schemes";
          "aurorae/themes".source = "${pkgs.flat-remix-kde}/share/aurorae/themes";
        };

        xdg.configFile."uwsm/env".source = "${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh";

        qt = {
          enable = true;
          platformTheme.name = "gtk";
          style.name = "gtk2";
        };

        home.packages = with pkgs; [
          inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland # hyprctl in PATH

          # Spell checking
          hunspell
          hunspellDicts.en_US
          hunspellDicts.es_MX
          hunspellDicts.pt_BR

          pavucontrol
          galaxy-buds-client
          obsidian
          android-tools
        ];
      };
    };

  sysModule =
    {
      pkgs,
      config,
      inputs,
      lib,
      ...
    }:
    {
      options.myCfg.westonOutput = lib.mkOption {
        type = lib.types.str;
        description = "Weston target-specific configuration";
      };

      config = {
        boot.kernelPackages = pkgs.lib.mkDefault pkgs.linuxPackages_cachyos;
        boot.kernel.sysctl."kernel.printk" = "3 3 3 3";
        boot.kernelParams = [
          "quiet"
          "splash"
          "loglevel=3"
          "systemd.show_status=auto"
          "nosgx"
          "udev.log_priority=3"
          "rd.systemd.show_status=auto"
        ];

        boot.plymouth.enable = true;
        boot.initrd.verbose = false;
        boot.initrd.systemd.enable = true;

        networking.networkmanager.enable = true;
        
        hardware = {
          graphics.enable = true;
          bluetooth.enable = true;
          bluetooth.powerOnBoot = true;
          bluetooth.settings = {
            General = {
              ControllerMode = "bredr";
            };
          };
          brillo.enable = true;
        };

        programs.appimage = {
          enable = true;
          binfmt = true;
        };

        # Reduce RAM cache for ejectable devices
        services.udev.extraRules = ''
          SUBSYSTEM=="block", ACTION=="add",\
            KERNEL=="sd[a-z]",\
            TAG+="systemd",\
            ENV{ID_USB_TYPE}=="disk",\
            ENV{SYSTEMD_WANTS}+="usb-dirty-pages-fix@$kernel.service"
        '';
        systemd.services."usb-dirty-pages-fix@" = {
          scriptArgs = "%i";
          script = ''
            if [ -z "$(df --output=source '/' | grep $1)" ]; then
                echo 1 > /sys/block/$1/bdi/strict_limit
                echo 16777216 > /sys/block/$1/bdi/max_bytes
            fi
          '';
          serviceConfig.Type = "oneshot";
        };

        services.displayManager = {
          enable = true;
          sddm = {
            enable = true;
            wayland.enable = true;
            wayland.compositorCommand = "${lib.getExe pkgs.weston} --shell=kiosk -c ${pkgs.writeText "weston.ini" ''
              [core]
              backend=drm
              ${config.myCfg.westonOutput}
            ''}";
            theme = "catppuccin-mocha";
            package = pkgs.kdePackages.sddm;
          };
        };

        systemd.services.lock-before-suspend = {
          enable = true;
          description = "Lock sessions before suspend";
          before = [ "sleep.target" ];
          wantedBy = [ "sleep.target" ];
          script = ''
            loginctl lock-sessions
            sleep 1
          '';
          serviceConfig.Type = "oneshot";
        };

        services.udisks2.enable = true;
        services.blueman.enable = true;
        services.pipewire = {
          enable = true;
          pulse.enable = true;
        };
        programs.dconf.enable = true;

        environment.systemPackages = [
          pkgs.catppuccin-sddm
        ];

        programs.hyprland = {
          enable = true;
          withUWSM = true;
          xwayland.enable = true;

          package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
          portalPackage =
            inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
        };

        environment.sessionVariables = rec {
          ELECTRON_OZONE_PLATFORM_HINT = "auto";
          NIXOS_OZONE_WL = 1;
          EDITOR = "vim";
          XCURSOR_THEME = "Bibata-Modern-Ice";
          XCURSOR_SIZE = 32;
          HYPRCURSOR_THEME = XCURSOR_THEME;
          HYPRCURSOR_SIZE = XCURSOR_SIZE;
        };

        security.pam.services.hyprlock = { };
        security.pam.services.login.kwallet = {
          enable = true;
          package = pkgs.kdePackages.kwallet-pam;
        };

        networking.firewall = rec {
          allowedTCPPortRanges = [
            {
              # KDE Connect
              from = 1714;
              to = 1764;
            }
          ];
          allowedUDPPortRanges = allowedTCPPortRanges;
        };
      };
    };
}
