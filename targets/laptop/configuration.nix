let
  screenName = "eDP-1";
in
{
  pkgs,
  sysImport,
  private,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix

    (sysImport ./../../common/base.nix)
    (sysImport ./../../common/desktop.nix)
    (sysImport ./../../common/shares.nix)

    (sysImport ./../../common/bundles/internet.nix)
  ];

  sops.defaultSopsFile = private.secretsFile;
  sops.age.keyFile = "/root/.config/sops/age/keys.txt";

  cfg.services.displayManager.sddm-weston.outputs = {
    "${screenName}" = {
      mode = "1920x1080@60";
    };
  };

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
  cfg.services.printing.enable = true;

  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "lock";
    HandlePowerKey = "suspend";
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
          workspace = map (i: "${toString i},monitor:${screenName},persistent:true") (range 1 9);
          general = {
            gaps_in = 5;
            gaps_out = 2;
            border_size = 2;
          };
          misc.vfr = true; # Power-saving
          misc.middle_click_paste = false;
        };
      };

      cfg.programs.waybar = {
        enable = true;
        fontSize = "14px";
        settings = [
          {
            modules-left = [ "battery" "cpu" "memory" "disk" "custom/ioperc" "mpris" "network" ];
            modules-center = [ "hyprland/workspaces" ];
            modules-right = [ "hyprland/language" "idle_inhibitor" "custom/brightness" "wireplumber" "bluetooth" "clock" "tray" ];
          }
        ];
      };

      dconf.settings = {
        "org/gnome/desktop/interface".gtk-enable-primary-paste = false;
      };
    };
}
