{
  hmModule =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    {
      imports = [ (import ./hyprland).hmModule ];

      config = {
        cfg.kdeglobals = {
          UiSettings."ColorScheme" = "Flat-Remix-Red-Darkest";
          Icons."Theme" = "Flat-Remix-Red-Dark";
        };

        cfg.programs.kitty.enable = true;

        programs.wofi = {
          enable = true;
          settings = {
            allow_images = true;
          };
        };

        catppuccin = {
          flavor = "mocha";
          fish.enable = true;
          waybar.enable = true;
          kitty.enable = true;
          mako.enable = true;
        };

        xdg.configFile."hypr/xdph.conf".source = (
          pkgs.writeText "xdph" ''
            screencopy {
              max_fps = 60
            }
          ''
        );

        xdg.configFile."wofi-power-menu.toml".source = (
          pkgs.writeText "wofi-power-menu-config" ''
            [menu.logout]
              cmd = "bash -c 'uwsm stop'"
          ''
        );

        cfg.programs.hyprlock.enable = true;

        services.hyprsunset.enable = true;
        services.hyprpolkitagent.enable = true;
        services.mako.enable = true;
        services.mako.settings.default-timeout = 5000;
        services.flameshot.enable = true;
        services.flameshot.settings.General = {
          useGrimAdapter = true;
          useJpgForClipboard = true;
          #disabledGrimWarning = true;
          disabledTrayIcon = true;
          showStartupLaunchMessage = false;
          showAbortNotification = false;
        };

        services.hyprpaper = {
          enable = true;
          settings = {
            ipc = "on";
            splash = "false";
          };
        };

        cfg.services.hypridle.enable = true;

        services.network-manager-applet.enable = true;
        services.blueman-applet.enable = true;
        services.udiskie.enable = true;
        services.udiskie.tray = "always";
        services.easyeffects.enable = true;
        services.psd.enable = true;
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

        systemd.user.services.syshud = {
          Unit = {
            Description = "Syshud OSD";
            After = [ "graphical-session.target" ];
            ConditionEnvironment = [ "WAYLAND_DISPLAY" ];
            PartOf = [ "graphical-session.target" ];
          };

          Service = {
            Type = "oneshot";
            ExecStart = lib.getExe pkgs.syshud;
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

          gtk4.theme = config.gtk.theme;

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

        xdg.configFile."uwsm/env".text = ''
          . /etc/set-environment
          . ${config.home.sessionVariablesPackage}
          export HYPRLAND_CONFIG="${config.xdg.configHome}/hypr/hyprland.lua"
        '';

        # KService expects an applications menu even outside a Plasma session.
        # UWSM prefixes the lookup with the compositor name, while shells
        # outside UWSM use the unprefixed name.
        xdg.configFile = {
          "menus/applications.menu".source =
            "${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu";
          "menus/hyprland-applications.menu".source =
            "${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu";
        };

        xdg.desktopEntries.scrcpy = {
          name = "Scrcpy";
          exec = lib.getExe pkgs.myScripts.scrcpy;
          terminal = false;
          type = "Application";
          categories = [ "Utility" ];
        };

        qt = {
          enable = true;
          platformTheme.name = "gtk";
          style.name = "gtk2";
        };

        fonts.fontconfig.enable = true;

        home.packages = with pkgs; [
          hyprland # hyprctl in PATH

          # Spell checking
          hunspell
          hunspellDicts.en_US
          hunspellDicts.es_MX
          hunspellDicts.pt_BR

          pavucontrol
          galaxy-buds-client
          obsidian
          android-tools
          nwg-displays

          # Fonts
          gyre-fonts
        ];

        home.sessionVariables = rec {
          GTK_PATH = "${pkgs.gnome-themes-extra}/lib/gtk-2.0:$GTK_PATH";
          ELECTRON_OZONE_PLATFORM_HINT = "auto";
          NIXOS_OZONE_WL = 1;
          XCURSOR_THEME = "Bibata-Modern-Ice";
          XCURSOR_SIZE = 32;
          HYPRCURSOR_THEME = XCURSOR_THEME;
          HYPRCURSOR_SIZE = XCURSOR_SIZE;
          SDL_VIDEODRIVER = "wayland";
        };

        cfg.shortcutHelp.rules = {
          tmux = {
            title = "tmux";
            match.terminalForegroundExecutables = [ "tmux" ];
            shortcuts = [
              ''\U2756 + B, C -- Create window''
              ''\U2756 + B, N -- Move to next window''
              ''\U2756 + B, P -- Move to previous window''
              ''\U2756 + B, & -- Close current window''
            ];
          };
          vim = {
            title = "vim";
            match.terminalForegroundExecutables = [
              "vim"
              "nvim"
            ];
            shortcuts = [
              ''"+y -- Copy selected to clipboard''
              ":%s/search/replace/gc -- Find/replace"
            ];
          };
        };
      };
    };

  sysModule =
    {
      pkgs,
      lib,
      ...
    }:
    let
      rustdeskSudo = pkgs.writeShellScriptBin "sudo" ''
        exec ${pkgs.sudo}/bin/sudo \
          --set-home \
          --preserve-env=WAYLAND_DISPLAY,DISPLAY,DBUS_SESSION_BUS_ADDRESS,XDG_CURRENT_DESKTOP,XDG_SESSION_TYPE,GST_PLUGIN_SYSTEM_PATH_1_0 \
          "$@"
      '';
      rustdeskService = pkgs.writeShellApplication {
        name = "rustdesk-service";
        runtimeInputs = with pkgs; [ systemd ];
        text = ''
          session_id=$(loginctl show-seat seat0 --property=ActiveSession --value)
          session_user=$(loginctl show-session "$session_id" --property=Name --value)
          session_environment=$(systemctl --user --machine="$session_user@.host" show-environment)

          session_var() {
            local wanted=$1
            local key
            local value

            while IFS='=' read -r key value; do
              if [[ $key == "$wanted" ]]; then
                printf '%s' "$value"
                return
              fi
            done <<< "$session_environment"
          }

          WAYLAND_DISPLAY="$(session_var WAYLAND_DISPLAY)"
          DISPLAY="$(session_var DISPLAY)"
          DBUS_SESSION_BUS_ADDRESS="$(session_var DBUS_SESSION_BUS_ADDRESS)"
          XDG_CURRENT_DESKTOP="$(session_var XDG_CURRENT_DESKTOP)"
          XDG_SESSION_TYPE="$(session_var XDG_SESSION_TYPE)"
          export WAYLAND_DISPLAY DISPLAY DBUS_SESSION_BUS_ADDRESS XDG_CURRENT_DESKTOP XDG_SESSION_TYPE

          exec ${lib.getExe pkgs.rustdesk} --service
        '';
      };
    in
    {
      config = {
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

        services.kmscon = {
          enable = true;
          hwRender = true;
          fonts = [
            {
              name = "DroidSansM Nerd Font";
              package = pkgs.nerd-fonts.droid-sans-mono;
            }
          ];
          extraConfig = ''
            font-size=14
            multi-monitor=largest
            mouse
          '';
        };

        networking.networkmanager = {
          enable = true;
          plugins = with pkgs; [
            networkmanager-openvpn
          ];
        };

        hardware = {
          graphics.enable = true;
          bluetooth.enable = true;
          bluetooth.powerOnBoot = false;
          bluetooth.settings.General = {
            Experimental = "330859bc-7506-492d-9370-9a6f0614037f";
            FastConnectable = true;
          };
          brillo.enable = true;
        };

        programs.appimage = {
          enable = true;
          binfmt = true;
        };

        # Android MTP/ADB
        services.udev.packages = [ pkgs.libmtp.out ];
        users.groups.adbusers = { };

        services.usbmuxd.enable = true;
        services.udev.extraRules = ''
          SUBSYSTEM=="block", ACTION=="add",\
            KERNEL=="sd[a-z]",\
            TAG+="systemd",\
            ENV{ID_USB_TYPE}=="disk",\
            ENV{SYSTEMD_WANTS}+="usb-dirty-pages-fix@$kernel.service"
        '';
        # Reduce RAM cache for ejectable devices
        systemd.services."usb-dirty-pages-fix@" = {
          scriptArgs = "%i";
          script = ''
            if [ -z "$(df --output=source '/' | grep $1)" ]; then
                echo 1 > /sys/block/$1/bdi/strict_limit
                echo 33554432 > /sys/block/$1/bdi/max_bytes
            fi
          '';
          serviceConfig.Type = "oneshot";
        };

        services.displayManager.enable = true;
        cfg.services.displayManager.sddm-weston = {
          enable = true;
          theme = "${
            pkgs.catppuccin-sddm.override {
              flavor = "mocha";
              accent = "mauve";
              disableBackground = true;
            }
          }/share/sddm/themes/catppuccin-mocha-mauve";
        };

        services.udisks2.enable = true;
        services.blueman.enable = true;
        services.pipewire = {
          enable = true;
          pulse.enable = true;
        };
        programs.dconf.enable = true;

        # RustDesk's unprivileged GUI uses this helper for Wayland input injection.
        # With the helper running it captures through ScreenCast, which XDPH supports,
        # instead of requiring the unsupported RemoteDesktop portal.
        hardware.uinput.enable = true;
        systemd.services.rustdesk = {
          description = "RustDesk service";
          after = [ "systemd-user-sessions.service" ];

          path = with pkgs; [
            rustdeskSudo
            coreutils
            procps
            systemd
          ];

          serviceConfig = {
            Type = "simple";
            ExecStart = lib.getExe rustdeskService;
            StateDirectory = "rustdesk-helper";
            KillMode = "mixed";
            TimeoutStopSec = 30;
            LimitNOFILE = 100000;
          };

          environment = {
            HOME = "/var/lib/rustdesk-helper";
            PULSE_LATENCY_MSEC = "60";
            PIPEWIRE_LATENCY = "1024/48000";
            # RustDesk 1.4.7 creates `pipewiresrc` directly, but its Nix wrapper
            # only includes GStreamer's core and base plugins.
            GST_PLUGIN_SYSTEM_PATH_1_0 = "${pkgs.pipewire}/lib/gstreamer-1.0";
          };
        };

        # Let an active local administrator start/stop only this immutable unit.
        # The Home Manager launcher starts it on demand; `rustdesk-off` stops it.
        security.polkit.extraConfig = ''
          polkit.addRule(function(action, subject) {
            if (action.id == "org.freedesktop.systemd1.manage-units" &&
                action.lookup("unit") == "rustdesk.service" &&
                ["start", "stop", "restart"].indexOf(action.lookup("verb")) >= 0 &&
                subject.active && subject.local && subject.isInGroup("wheel")) {
              return polkit.Result.YES;
            }
          });
        '';

        programs.hyprland = {
          enable = true;
          withUWSM = true;
          xwayland.enable = true;

          package = pkgs.hyprland;
          portalPackage = pkgs.xdg-desktop-portal-hyprland;
        };

        xdg.portal = {
          enable = true;
          extraPortals =
            with pkgs;
            lib.mkForce [
              kdePackages.xdg-desktop-portal-kde
              xdg-desktop-portal-gtk
              xdg-desktop-portal-hyprland
            ];

          config = {
            common = {
              default = [
                "hyprland"
                "gtk"
              ];
              "org.freedesktop.impl.portal.FileChooser" = "kde";
            };
          };
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
