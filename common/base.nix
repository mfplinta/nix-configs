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
        _module.args.mkMutableGeneratedFile =
          {
            source,
            target,
            backupExtension ? "old-hm",
            mode ? "0600",
          }:
          let
            sourcePath = toString source;
            targetPath = "${config.home.homeDirectory}/${target}";
            backupPath = "${targetPath}.${backupExtension}";
          in
          lib.hm.dag.entryAfter [ "linkGeneration" ] ''
            generated=${lib.escapeShellArg sourcePath}
            target=${lib.escapeShellArg targetPath}
            backup=${lib.escapeShellArg backupPath}

            if [[ ( -e "$target" || -L "$target" ) ]] && ${lib.getExe' pkgs.diffutils "cmp"} --silent -- "$generated" "$target"; then
              verboseEcho "Skipping '$target' because its content is unchanged"
            else
              if [[ -e "$target" || -L "$target" ]]; then
                if [[ -e "$backup" || -L "$backup" ]]; then
                  run ${lib.getExe' pkgs.coreutils "rm"} -f "$backup"
                fi
                run ${lib.getExe' pkgs.coreutils "mv"} "$target" "$backup"
              fi

              run ${lib.getExe' pkgs.coreutils "install"} -Dm${lib.escapeShellArg mode} -- "$generated" "$target"
            fi
          '';

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

        programs.tmux = {
          enable = true;
          historyLimit = 100000;
          extraConfig = "set -g mouse on";
        };

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
          git-filter-repo
        ];
      };
    };
}
