let
  leftMonitor = "DP-2";
  centerMonitor = "DP-3";
  rightMonitor = "DP-1";
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
    (sysImport ./../../common/programs/jdownloader2.nix)
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
  boot.blacklistedKernelModules = [ "nouveau" ];
  boot.initrd.kernelModules = [
    "e1000e"
  ];
  boot.kernelModules = [ "ddcci-backlight" ];
  boot.extraModulePackages = with config.boot.kernelPackages; [
    ddcci-driver
  ];

  # Encrypted root
  boot.initrd.network.flushBeforeStage2 = true;
  boot.initrd.systemd.network.enable = true;
  boot.initrd.systemd.network.wait-online.anyInterface = true;
  boot.initrd.systemd.network.wait-online.timeout = 10;
  boot.initrd.systemd.network.networks."10-lan" = {
    matchConfig.Type = "ether";
    networkConfig.DHCP = "ipv4";
  };
  boot.initrd.clevis.enable = true;
  boot.initrd.clevis.useTang = true;
  boot.initrd.clevis.devices."crypted".secretFile = /root/tang.jwe;

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
    nvidia =
      {
        powerManagement.enable = true;
        modesetting.enable = true;
        nvidiaSettings = true;
        open = true;
      };
    i2c.enable = true;
  };

  programs.virt-manager.enable = true;
  virtualisation.libvirtd.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;

  environment.sessionVariables = {
    # Nvidia-specific
    LIBVA_DRIVER_NAME = "nvidia";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    NVD_BACKEND = "direct";
    WLR_NO_HARDWARE_CURSORS = "1";
  };

  networking.firewall.allowedTCPPorts = [
    8000 # Dev
  ];

  users.users.matheus = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "scanner"
      "lp"
      "video"
      "libvirtd"
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
          workspace =
            map (
              i:
              "${toString i},monitor:${
                elemAt [ "${centerMonitor}" "${leftMonitor}" "${rightMonitor}" ] ((i - 1) / 3)
              },persistent:true${if i == 1 then ",default:true" else ""}"
            ) (range 1 9)
            ++ [
              "name:win,monitor:${centerMonitor},persistent:true"
            ];
          windowrule =
            let
              moonlight = "initialTitle:^(.*)(- Moonlight)";
            in
            [
              "monitor ${leftMonitor},class:(flameshot)" # Flameshot 0x0 on left monitor

              "workspace name:win,${moonlight}"
              "fullscreen,${moonlight}"
              "idleinhibit focus,${moonlight}"
            ];
          bind = [
            "SUPER, W, workspace, name:win"
            ", XF86Calculator, exec, uwsm app -- ${getExe pkgs.qalculate-gtk}"
          ];
          cursor."no_hardware_cursors" = 1;
          experimental."xx_color_management_v4" = true;
          render."cm_fs_passthrough" = 2;
        };

        hyprpanel.layout = {
          "bar.launcher.icon" = "";
          "bar.layouts" = {
            "${leftMonitor}" = {
              left = [ ];
              middle = [ "workspaces" ];
              right = [ ];
            };
            "${centerMonitor}" = {
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
            "${rightMonitor}" = {
              left = [ ];
              middle = [ "workspaces" ];
              right = [ ];
            };
          };
        };
      };

      dconf.settings = {
        "org/virt-manager/virt-manager/connections" = {
          autoconnect = ["qemu:///system"];
          uris = ["qemu:///system"];
        };
      };

      home.packages =
        with pkgs;
        with pkgs.kdePackages;
        [
          moonlight-qt
          blender
        ];
    };
}
