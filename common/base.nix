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

        home.stateVersion = "24.11";
      };
    };

  sysModule =
    { pkgs, config, lib, sysImport, ... }:
    {
      imports = [
        (sysImport ./programs/fish.nix)
      ];

      options.myCfg = {
        vmagentEnable = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        vmagentRemoteWriteUrl = lib.mkOption {
          type = lib.types.str;
        };
        vmagentUsername = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
        };
        vmagentPasswordFile = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
        };
      };

      config = lib.mkMerge [
        {
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
            smartmontools
            netcat-gnu
            sops
          ];
        }
        (lib.mkIf config.myCfg.vmagentEnable {
          services.vmagent = {
            enable = true;
            remoteWrite = {
              url = config.myCfg.vmagentRemoteWriteUrl;
              basicAuthUsername = config.myCfg.vmagentUsername;
              basicAuthPasswordFile = config.myCfg.vmagentPasswordFile;
            };
            prometheusConfig = {
              scrape_configs = [
                {
                  job_name = "node-exporter";
                  scrape_interval = "60s";
                  static_configs = [
                    {
                      targets = [ "127.0.0.1:9100" ];
                      labels.instance = config.networking.hostName;
                    }
                  ];
                }
              ];
            };
          };

          services.prometheus.exporters.node = {
            enable = true;
            port = 9100;
            enabledCollectors = [ "systemd" ];
          };
        })
      ];
    };
}
