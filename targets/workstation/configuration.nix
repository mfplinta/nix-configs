let
  leftMonitor = "DP-1";
  centerMonitor = "DP-3";
  rightMonitor = "HDMI-A-1";
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
    name=${leftMonitor}
    mode=off

    [output]
    name=${centerMonitor}
    mode=3840x2160@60

    [output]
    name=${rightMonitor}
    mode=off
  '';

  boot.kernelParams = [
    "video=${centerMonitor}:3840x2160@60"
  ];
  boot.initrd.kernelModules = [
    "nvidia"
    "e1000e"
  ];
  boot.kernelModules = [ "ddcci-backlight" ];
  boot.extraModulePackages = with config.boot.kernelPackages; [
    nvidia_x11
    ddcci-driver
  ];
  services.scx.enable = true;
  services.scx.scheduler = "scx_bpfland";

  services.hardware.openrgb.enable = true;
  services.xserver.videoDrivers = [ "nvidia" ];
  services.udev.extraRules = ''
    SUBSYSTEM=="i2c-dev", ACTION=="add",\
      ATTR{name}=="NVIDIA i2c adapter*",\
      TAG+="ddcci",\
      TAG+="systemd",\
      ENV{SYSTEMD_WANTS}+="ddcci@$kernel.service"
  '';
  systemd.services."ddcci@" = {
    scriptArgs = "%i";
    script = ''
      echo ddcci: device $1 appeared. Waiting for greeter
      while ! (loginctl | grep greeter &> /dev/null); do
        sleep 1
      done
      echo ddcci: greeter appeared. Waiting for login to enable ddcci
      while loginctl | grep greeter &> /dev/null; do
        sleep 1
      done
      sleep 5
      echo ddcci: trying to attach ddcci to $1
      i=0
      id=$(echo $1 | cut -d "-" -f 2)
      if ${pkgs.ddcutil}/bin/ddcutil getvcp 10 -b $id; then
        echo ddcci 0x37 > /sys/bus/i2c/devices/$1/new_device
      fi
    '';
    serviceConfig.Type = "oneshot";
  };

  hardware = {
    nvidia = {
      powerManagement.enable = true;
      modesetting.enable = true;
      open = true;
      nvidiaSettings = true;
    };
    i2c.enable = true;
  };

  environment.sessionVariables = {
    # Nvidia-specific
    LIBVA_DRIVER_NAME = "nvidia";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    NVD_BACKEND = "direct";
    WLR_NO_HARDWARE_CURSORS = "1";
  };

  networking.firewall = rec {
    allowedTCPPorts = [
      53317 # LocalSend
      8000 # Dev
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
        mainMonitor = centerMonitor;

        hyprland = with pkgs.lib; {
          monitor = [
            "${centerMonitor},3840x2160@60,0x0,1"
            "${leftMonitor},1920x1080@74.97,auto-left,1,transform,3"
            "${rightMonitor},1920x1080@74.97,auto-right,1,transform,1"
          ];
          workspace = map (
            i:
            "${toString i},monitor:${
              elemAt [ "${centerMonitor}" "${leftMonitor}" "${rightMonitor}" ] ((i - 1) / 3)
            },persistent:true${if i == 1 then ",default:true" else ""}"
          ) (range 1 9);
          windowrule =
            let
              moonlight = "initialTitle:^(.*)(- Moonlight)";
            in
            [
              "monitor ${leftMonitor},class:(flameshot)" # Flameshot 0x0 on left monitor

              "monitor ${centerMonitor},${moonlight}"
              "fullscreen,${moonlight}"
              "idleinhibit focus,${moonlight}"
            ];
          bind = [
            ", XF86Calculator, exec, uwsm app -- ${getExe pkgs.qalculate-gtk}"
          ];
          cursor."no_hardware_cursors" = 1;
          experimental."xx_color_management_v4" = true;
          render."cm_fs_passthrough" = 2;
        };

        hyprpanel.layout = {
          "bar.launcher.icon" = "";
          "bar.layouts" = {
            "0" = {
              left = [ ];
              middle = [ "workspaces" ];
              right = [ ];
            };
            "1" = {
              left = [ ];
              middle = [ "workspaces" ];
              right = [ ];
            };
            "2" = {
              left = [
                "workspaces"
                "cpu"
                "ram"
                "storage"
                "kbinput"
              ];
              middle = [
                "media"
                "netstat"
              ];
              right = [
                "hypridle"
                "hyprsunset"
                "custom/brightness"
                "volume"
                "network"
                "bluetooth"
                "systray"
                "clock"
                "notifications"
              ];
            };
          };
        };
      };

      home.packages =
        with pkgs;
        with pkgs.kdePackages;
        [
          moonlight-qt
        ];
    };
}
