{
  hmModule =
    {
      pkgs,
      lib,
      config,
      private,
      sysConfig,
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
          configFile."gh/config.yml".source = (pkgs.formats.yaml { }).generate "gh-config.yml" {
            version = "1";
            git_protocol = "https";
            telemetry = "disabled";
          };
          configFile."gh/hosts.yml".source =
            config.lib.file.mkOutOfStoreSymlink sysConfig.sops.templates.gh-hosts.path;
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

        programs.ssh = {
          enable = true;
          enableDefaultConfig = false;
          settings = {
            "*" = {
              ForwardAgent = false;
              AddKeysToAgent = "no";
              Compression = false;
              ServerAliveInterval = 0;
              ServerAliveCountMax = 3;
              HashKnownHosts = false;
              UserKnownHostsFile = "~/.ssh/known_hosts";
              ControlMaster = "no";
              ControlPath = "~/.ssh/master-%r@%n:%p";
              ControlPersist = "no";
            };
          }
          // private.ssh.settings;
        };

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

        sops.secrets.github_pat_readonly = lib.mkIf (config.home-manager.users ? matheus) {
          owner = "matheus";
          mode = "0400";
        };
        sops.templates.gh-hosts = lib.mkIf (config.home-manager.users ? matheus) {
          owner = "matheus";
          mode = "0400";
          content = ''
            github.com:
              user: mfplinta
              oauth_token: ${config.sops.placeholder.github_pat_readonly}
              git_protocol: https
              users:
                mfplinta:
                  oauth_token: ${config.sops.placeholder.github_pat_readonly}
          '';
        };

        programs.nh = {
          enable = true;
          clean = {
            enable = true;
            extraArgs = "--keep 5";
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
          gh
          file
          ripgrep
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
