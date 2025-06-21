{
  hmModule =
    { pkgs, hmModule-nix-index, lib, config, ... }:
    {
      imports = [
        hmModule-nix-index
      ];

      options.myCfg.kdeglobals = lib.mkOption {
        type = with lib.types; attrsOf anything;
        default = {};
        description = ".kdeglobals configuration";
      };

      config = {
        xdg.configFile."kdeglobals".source = (pkgs.formats.ini { }).generate "kdeglobals" config.myCfg.kdeglobals;

        xdg.userDirs = {
          enable = true;
          createDirectories = true;
        };

        programs.nix-index.enable = true;
        programs.nix-index.symlinkToCacheHome = true;
      };
    };

  sysModule =
    { pkgs, config, ... }:
    {
      boot.loader.systemd-boot.enable = true;
      boot.loader.timeout = 0;
      boot.loader.efi.canTouchEfiVariables = true;
      boot.kernelPackages = pkgs.linuxPackages_cachyos;
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

      security.sudo.extraConfig = ''
        Defaults pwfeedback,insults
      '';

      programs.appimage = {
        enable = true;
        binfmt = true;
      };

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

      environment.systemPackages = with pkgs; [
        vim
        wget
        usbutils
        pciutils
        htop
        p7zip
        unzip
        unrar
        bind
        jq
        git

        # Nix LSP
        nil
        nixfmt-rfc-style

        # FS
        exfatprogs
      ];
    };
}
