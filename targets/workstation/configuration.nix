let
  leftMonitor = "DP-1";
  centerMonitor = "DP-3";
  rightMonitor = "HDMI-A-1";
in
{
  pkgs,
  inputs,
  wrapper-manager,
  config,
  ...
}:
let
  sysImport = module: (import module).sysModule;
in
{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix

    (sysImport ./../../common/base.nix)
    (sysImport ./../../common/desktop.nix)
    (sysImport ./../../common/shares.nix)
    (sysImport ./../../common/containers.nix)
    (sysImport ./../../common/printing.nix)

    (sysImport ./../../common/programs/fish.nix)
    (sysImport ./../../common/programs/brave.nix)
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
  boot.initrd.kernelModules = [ "nvidia" "e1000e" ];
  boot.kernelModules = [ "ddcci-backlight" ];
  boot.extraModulePackages = with config.boot.kernelPackages; [ nvidia_x11 ddcci-driver ];

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
      pkgs,
      lib,
      config,
      ...
    }:
    let
      hmImport =
        module:
        (import module).hmModule {
          inherit
            inputs
            pkgs
            wrapper-manager
            lib
            config
            ;
        };
    in
    {
      imports = [
        (hmImport ./../../common/base.nix)
        (hmImport ./../../common/desktop.nix)
        (hmImport ./../../common/shares.nix)

        (hmImport ./../../common/programs/fish.nix)
        (hmImport ./../../common/programs/dolphin.nix)
        (hmImport ./../../common/programs/brave.nix)
        (hmImport ./../../common/programs/mpv.nix)
        (hmImport ./../../common/programs/nomacs.nix)
      ];

      myCfg = {
        mainMonitor = centerMonitor;

        hyprland = with lib; {
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
          windowrule = [
            "monitor ${leftMonitor},class:(flameshot)" # Flameshot 0x0 on left monitor
            "monitor ${centerMonitor},initialTitle:^(.*)(- Moonlight)"
          ];
          bind = [
            ", XF86Calculator, exec, uwsm app -- ${getExe pkgs.qalculate-gtk}"
          ];
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

      xdg = {
        mimeApps.enable = true;
        mimeApps.defaultApplications =
          let
            textEditor = "org.kde.kate.desktop";
            torrentClient = "org.qbittorrent.qBittorrent.desktop";
          in
          {
            "application/x-bittorrent" = [ torrentClient ];
            "application/pdf" = [ "okularApplication_pdf.desktop" ];
            "application/octet-stream" = [
              "veracrypt.desktop"
              "imhex.desktop"
              textEditor
            ];
            "text/plain" = [ textEditor ];
            "x-scheme-handler/magnet" = [ torrentClient ];
          };
      };

      home.packages =
        with pkgs;
        with pkgs.kdePackages;
        [
          kate
          okular
          ark
          veracrypt
          imhex
          qalculate-gtk

          # Internet
          qbittorrent
          localsend

          # Media
          moonlight-qt
          anydesk

          # Office
          simple-scan
          onlyoffice-desktopeditors
        ];

      home.stateVersion = "24.11";
    };

  system.stateVersion = "24.11";
}
