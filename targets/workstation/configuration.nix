let
  leftMonitor = "DP-1";
  centerMonitor = "DP-2";
  rightMonitor = "DP-3";
in
{
  pkgs,
  lib,
  sysImport,
  config,
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
    (sysImport ./../../common/containers.nix)

    (sysImport ./../../common/bundles/internet.nix)
  ];

  sops.defaultSopsFile = private.secretsFile;
  sops.age.keyFile = "/root/.config/sops/age/keys.txt";

  cfg.services.displayManager.sddm-weston.outputs = {
    "${leftMonitor}" = {
      mode = "off";
    };
    "${centerMonitor}" = {
      mode = "3840x2160@60";
    };
    "${rightMonitor}" = {
      mode = "off";
    };
  };

  boot.kernelParams = [
    "video=${centerMonitor}:3840x2160@60"
    "intel_iommu=on"
    "vfio-pci.ids=10de:1cb6,10de:0fb9"
  ];
  boot.blacklistedKernelModules = [ "nouveau" ];
  boot.initrd.kernelModules = [
    "e1000e"
  ];
  boot.kernelModules =  lib.mkBefore [
    "vfio"
    "vfio_iommu_type1"
    "vfio_pci"
    "vfio_virqfd"
    "ddcci-backlight"
    "kvmfr"
    "uinput"
  ];
  boot.extraModulePackages = with config.boot.kernelPackages; [
    ddcci-driver
    kvmfr
  ];
  boot.extraModprobeConfig = ''
    options kvmfr static_size_mb=128
  '';

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
  boot.initrd.clevis.devices."crypted".secretFile = "/root/tang.jwe";

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
    SUBSYSTEM=="kvmfr", OWNER="matheus", GROUP="kvm", MODE="0660"
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
  services.nvibrant = {
    enable = true;
    vibrancy = [
      "0"
      "0"
      "0"
      "0"
      "0"
      "0"
      "0"
    ];
    dithering = [
      "2"
      "0"
      "0"
      "2"
      "0"
      "2"
      "0"
    ];
  };

  hardware = {
    nvidia = {
      powerManagement.enable = true;
      modesetting.enable = true;
      nvidiaSettings = true;
      open = true;
      package = config.boot.kernelPackages.nvidiaPackages.latest;
    };
    i2c.enable = true;
    opentabletdriver.enable = true;
    uinput.enable = true;
  };

  cfg.services.nvidia_oc = {
    enable = true;
    powerLimit = 200;
  };

  environment.sessionVariables = {
    # Nvidia-specific
    LIBVA_DRIVER_NAME = "nvidia";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    NVD_BACKEND = "direct";
    WLR_NO_HARDWARE_CURSORS = "1";
  };

  environment.etc."nvidia/nvidia-application-profiles-rc.d/50-limit-free-buffer-pool-in-wayland-compositors.json".text =
    builtins.toJSON {
      rules = [
        {
          pattern = {
            feature = "procname";
            matches = ".Hyprland-wrapped";
          };
          profile = "Limit Free Buffer Pool On Wayland Compositors";
        }
        {
          pattern = {
            feature = "procname";
            matches = "Hyprland";
          };
          profile = "Limit Free Buffer Pool On Wayland Compositors";
        }
      ];
      profiles = [
        {
          name = "Limit Free Buffer Pool On Wayland Compositors";
          settings = [
            {
              key = "GLVidHeapReuseRatio";
              value = 0;
            }
          ];
        }
      ];
    };

  networking.firewall.allowedTCPPorts = [
    8000 # Dev
  ];

  networking.firewall.allowedUDPPorts = [
    59010
    59011 # Soundwire
  ];

  users.users.matheus = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "scanner"
      "lp"
      "video"
      "libvirtd"
      "dialout"
      "kvm"
      "adbusers"
    ];
  };

  cfg.services.printing.enable = true;
  cfg.virtualisation.quadlet.enable = true;
  cfg.virtualisation.libvirt.enable = true;
  cfg.virtualisation.distrobox.enable = true;

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

      cfg.hyprland = with pkgs.lib; {
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
            "name:win,monitor:${centerMonitor},persistent:false"
          ];
        windowrule =
          let
            moonlight = "match:initial_title ^(.*)(- Moonlight)";
          in
          [
            "match:title (flameshot),monitor ${leftMonitor}" # Flameshot 0x0 on left monitor
            "match:title (flameshot),size 6000 2160"

            "${moonlight},workspace name:win"
            "${moonlight},fullscreen 1"
            "${moonlight},idle_inhibit focus"
          ];
        bind = [
          "SUPER, W, workspace, name:win"
          ", XF86Calculator, exec, uwsm app -- ${getExe pkgs.qalculate-gtk}"
        ];
        cursor."no_hardware_cursors" = 1;
      };

      cfg.programs.dolphin.enable = true;
      cfg.programs.hyprlock.monitor = centerMonitor;
      cfg.programs.waybar.enable = true;
      cfg.programs.waybar.settings = [
        {
          output = leftMonitor;
          modules-center = [ "hyprland/workspaces" ];
        }
        {
          output = centerMonitor;
          modules-left = [
            "hyprland/workspaces"
            "cpu"
            "memory"
            "disk"
            "custom/ioperc"
            "network"
          ];
          modules-center = [ "mpris" ];
          modules-right = [
            "hyprland/language"
            "idle_inhibitor"
            "custom/brightness"
            "wireplumber#sink"
            "wireplumber#source"
            "bluetooth"
            "clock"
            "tray"
          ];
        }
        {
          output = rightMonitor;
          modules-center = [ "hyprland/workspaces" ];
        }
      ];

      programs.looking-glass-client.enable = true;

      services.easyeffects = {
        preset = "default";
        extraPresets = {
          default = {
            input = {
              blocklist = [ ];
              plugins_order = [
                "stereo_tools#0"
                "rnnoise#0"
              ];
              "stereo_tools#0" = {
                mode = "LR > LL (Mono Left Channel)";
              };
              "rnnoise#0" = {
                "enable-vad" = false;
                release = 50.0;
              };
            };
          };
        };
      };

      cfg.services.jdownloader2.enable = true;

      home.packages =
        with pkgs;
        with pkgs.kdePackages;
        [
          moonlight-qt
          blender
          soundwireserver
          unstable.android-studio-full
        ];
    };
}
