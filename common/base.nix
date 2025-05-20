{
  hmModule =
    { pkgs, inputs, lib, config, ... }:
    {
      imports = [
        inputs.nix-index-database.hmModules.nix-index
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
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.backupFileExtension = "old-hm";

      nix.settings = {
        substituters = [ "https://hyprland.cachix.org" ];
        trusted-public-keys = [ "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=" ];
        experimental-features = [
          "nix-command"
          "flakes"
        ];
      };
      nixpkgs.config.allowUnfree = true;

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
      boot.initrd.systemd.network.networks."10-lan" = {
        matchConfig.Type = "ether";
        networkConfig.DHCP = "ipv4";
      };
      boot.initrd.clevis.enable = true;
      boot.initrd.clevis.useTang = true;
      boot.initrd.clevis.devices."crypted".secretFile = /root/tang.jwe;

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
      ];
    };
}
