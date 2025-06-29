{
  hmModule =
    { pkgs, hmModule-nix-index, lib, config, hmImport, ... }:
    {
      imports = [
        hmModule-nix-index

        (hmImport ./programs/fish.nix)
        (hmImport ./programs/gparted.nix)
      ];

      options.myCfg.kdeglobals = lib.mkOption {
        type = with lib.types; attrsOf anything;
        default = {};
        description = ".kdeglobals configuration";
      };

      config = {
        xdg = {
          configFile."kdeglobals".source = (pkgs.formats.ini { }).generate "kdeglobals" config.myCfg.kdeglobals;
          userDirs.enable = true;
          userDirs.createDirectories = true;
          mimeApps.enable = true;
        };

        programs.nix-index.enable = true;
        programs.nix-index.symlinkToCacheHome = true;

        programs.git = {
          enable = true;
          userName = "Matheus Plinta";
          userEmail = "mfplinta@gmail.com";
        };

        home.packages = with pkgs; [
          galaxy-buds-client
        ];

        home.stateVersion = "24.11";
      };
    };

  sysModule =
    { pkgs, sysImport, ... }:
    {
      imports = [
        (sysImport ./programs/fish.nix)
      ];

      boot.loader.systemd-boot.enable = true;
      boot.loader.timeout = 0;
      boot.loader.efi.canTouchEfiVariables = true;
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
      boot.tmp.useTmpfs = true;

      boot.plymouth.enable = true;
      boot.initrd.verbose = false;
      boot.initrd.systemd.enable = true;

      security.sudo.extraConfig = ''
        Defaults pwfeedback,insults
        Defaults timestamp_timeout=15
      '';

      networking.networkmanager.enable = true;
      time.timeZone = "America/Denver";

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

      programs.appimage = {
        enable = true;
        binfmt = true;
      };

      programs.htop = {
        enable = true;
        settings = {
          show_cpu_frequency = true;
          show_cpu_temperature = true;
        };
      };

      environment.systemPackages = with pkgs; [
        vim
        wget
        usbutils
        pciutils
        p7zip
        unzip
        unrar
        bind
        jq
        git
      ];
    };
}
