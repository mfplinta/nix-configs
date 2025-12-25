let
  screenName = "eDP-1";
in
{
  pkgs,
  sysImport,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix

    (sysImport ./../../common/base.nix)
    (sysImport ./../../common/desktop.nix)
    (sysImport ./../../common/shares.nix)
    (sysImport ./../../common/containers.nix)
    (sysImport ./../../common/printing.nix)

    (sysImport ./../../common/bundles/internet.nix)
  ];

  cfg.westonOutput = ''
    [output]
    name=${screenName}
    mode=1920x1080@60
  '';

  boot.kernelParams = [
    "video=${screenName}:1920x1080@60"
    "mem_sleep_default=deep"
    "i915.force_probe=!9a49"
    "xe.force_probe=9a49"
  ];
  boot.initrd.kernelModules = [ "i915" ];

  hardware.graphics.extraPackages = with pkgs; [
    intel-vaapi-driver
    intel-media-driver
    vpl-gpu-rt
    intel-compute-runtime-legacy1
  ];

  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;

  services.logind = {
    lidSwitch = "suspend";
    lidSwitchExternalPower = "lock";
    powerKey = "suspend";
  };

  users.users.matheus = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "scanner"
      "lp"
      "video"
    ];
  };

  home-manager.users.matheus =
    {
      hmImport,
      ...
    }:
    {
      imports = [
        (hmImport ./../../common/base.nix)
        (hmImport ./../../common/desktop.nix)
        (hmImport ./../../common/shares.nix)

        (hmImport ./../../common/bundles/development.nix)
        (hmImport ./../../common/bundles/multimedia.nix)
        (hmImport ./../../common/bundles/internet.nix)
        (hmImport ./../../common/bundles/utilities.nix)
        (hmImport ./../../common/bundles/office.nix)
      ];

      cfg.programs.dolphin.enable = true;

      cfg = {
        mainMonitor = screenName;

        hyprland = with pkgs.lib; {
          monitor = [
            "${screenName},1920x1080@60,0x0,1"
          ];
          workspace = map (i: "1,monitor:${screenName},persistent:true") (range 1 9);
          general = {
            gaps_in = 5;
            gaps_out = 5;
            border_size = 2;
          };
          misc.vfr = true; # Power-saving
          misc.middle_click_paste = false;
        };

        hyprpanel = {
          "bar.launcher.icon" = "";
          "bar.clock.format" = "%a %b %d  %I:%M %p";
          "bar.layouts" = {
            "0" = {
              left = [
                "battery"
                "cpu"
                "ram"
                "storage"
                "custom/ioperc"
                "kbinput"
                "media"
              ];
              middle = [
                "workspaces"
              ];
              right = [
                "hypridle"
                "hyprsunset"
                "volume"
                "bluetooth"
                "systray"
                "clock"
                "notifications"
              ];
            };
          };
          "theme.font.size" = "1rem";
        };
      };

      dconf.settings = {
        "org/gnome/desktop/interface" = {
          "gtk-enable-primary-paste" = false;
        };
      };
    };
}
