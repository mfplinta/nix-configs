{
  hmModule =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    {
      options.cfg.kdeglobals = lib.mkOption {
        type = with lib.types; attrsOf anything;
        default = { };
        description = ".kdeglobals configuration";
      };

      config = {
        xdg = {
          configFile."kdeglobals".source = (pkgs.formats.ini { }).generate "kdeglobals" config.cfg.kdeglobals;
          userDirs.enable = true;
          userDirs.createDirectories = true;
          userDirs.setSessionVariables = true;
          userDirs.extraConfig = {
            PROJECTS = "Projects";
          };
          mimeApps.enable = true;
        };

        programs.nix-index.enable = true;
        programs.nix-index.symlinkToCacheHome = true;

        home.stateVersion = "24.11";
      };
    };

  sysModule =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      config = {
        boot.loader.systemd-boot.enable = true;
        boot.loader.timeout = 0;
        boot.loader.efi.canTouchEfiVariables = true;
        boot.tmp.useTmpfs = true;
        boot.tmp.tmpfsSize = "125%";

        # TODO: Temp dirty frag fix
        boot.extraModprobeConfig = ''
          install esp4 ${pkgs.coreutils}/bin/false
          install esp6 ${pkgs.coreutils}/bin/false
          install rxrpc ${pkgs.coreutils}/bin/false
        '';
        boot.blacklistedKernelModules = [
          "esp4"
          "esp6"
          "rxrpc"
        ];

        # Zram swap
        zramSwap.enable = true;
        zramSwap.memoryPercent = 100;
        boot.kernel.sysctl."vm.swappiness" = 180;
        boot.kernel.sysctl."vm.watermark_boost_factor" = 0;
        boot.kernel.sysctl."vm.watermark_scale_factor" = 125;
        boot.kernel.sysctl."vm.page-cluster" = 0;

        system.modulesTree = [ (lib.getOutput "modules" config.boot.kernelPackages.kernel) ];

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

        programs.git = {
          enable = true;
          lfs.enable = true;
          config = {
            user.name = "Matheus Plinta";
            user.email = "mfplinta@gmail.com";
            url."https://github.com/" = {
              insteadOf = [
                "gh:"
                "github:"
              ];
            };
            submodule.recurse = true;
          };
        };

        cfg.programs.vim.enable = true;
        cfg.programs.fish.enable = true;

        environment.systemPackages = with pkgs; [
          wget
          usbutils
          pciutils
          p7zip
          unzip
          unrar
          zip
          bind
          jq
          smartmontools
          netcat-gnu
          sops
          killall
          lm_sensors
          net-tools
          lsof
          strace
          tcpdump
          screen
          nixfmt
          myScripts.rebuild
        ];
      };
    };
}
