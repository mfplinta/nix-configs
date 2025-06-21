let
  screenName = "eDP-1";
in
{
  pkgs,
  sysImport,
  config,
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

  myCfg.westonOutput = ''
    [output]
    name=${screenName}
    mode=1920x1080@60
  '';

  boot.kernelModules = [ "msi-ec" ];
  boot.extraModulePackages = [ config.boot.kernelPackages.msi-ec ];
  boot.kernelParams = [
    "video=${screenName}:1920x1080@60"
    "mem_sleep_default=deep"
  ];
  boot.initrd.kernelModules = [ "i915" ];

  hardware.graphics.extraPackages = with pkgs; [
    vaapiIntel
    intel-media-driver
    vpl-gpu-rt
  ];

  networking.firewall = rec {
    allowedTCPPorts = [
      53317 # LocalSend
    ];
    allowedUDPPorts = allowedTCPPorts;
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

        (hmImport ./../../common/programs/dolphin.nix)
      ];

      myCfg = {
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
        };

        hyprpanel.layout = {
          "bar.launcher.icon" = "";
          "bar.layouts" = {
            "0" = {
              left = [
                "custom/battery"
                "cpu"
                "ram"
                "storage"
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
          "menus.clock.time.hideSeconds" = true;
          "theme.font.size" = "1rem";
        };
      };
    };
}
