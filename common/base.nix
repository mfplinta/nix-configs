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
      boot.tmp.useTmpfs = true;

      security.sudo.extraConfig = ''
        Defaults pwfeedback,insults
        Defaults timestamp_timeout=15
      '';

      time.timeZone = "America/Denver";
      i18n.defaultLocale = "en_US.UTF-8";

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
