{
  sysModule =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      inherit (lib)
        mkEnableOption
        mkOption
        types
        mkIf
        ;
      cfg = config.cfg.services.nextcloud;
    in
    {
      options.cfg.services.nextcloud = {
        enable = mkEnableOption "nextcloud";
        adminUsername = mkOption {
          type = types.str;
          default = "admin";
        };
        adminPasswordFile = mkOption {
          type = types.str;
        };
        trustedDomains = mkOption {
          type = types.listOf types.str;
          default = [ ];
        };
        trustedProxies = mkOption {
          type = types.listOf types.str;
          default = [ ];
        };
        port = mkOption {
          type = types.int;
          default = 8000;
        };
        onlyoffice.enable = mkEnableOption "nextcloud onlyoffice";
        onlyoffice.jwtSecretFile = mkOption {
          type = types.str;
        };
        onlyoffice.securityNonceFile = mkOption {
          type = types.str;
        };
        onlyoffice.port = mkOption {
          type = types.int;
          default = 8001;
        };
      };

      config = mkIf cfg.enable {
        environment.systemPackages = with pkgs; [
          config.services.nextcloud.occ
          cron
          ghostscript
          exiftool
        ];

        services.onlyoffice = {
          enable = true;
          hostname = "onlyoffice";
          port = 10000;
          jwtSecretFile = cfg.onlyoffice.jwtSecretFile;
          securityNonceFile = cfg.onlyoffice.securityNonceFile;
        };

        services.nginx.virtualHosts."${config.services.onlyoffice.hostname}".listen = [
          {
            addr = "0.0.0.0";
            port = cfg.onlyoffice.port;
          }
        ];

        services.nextcloud = {
          enable = true;
          package = pkgs.nextcloud32;
          extraAppsEnable = true;
          extraApps = {
            inherit (pkgs.nextcloud32.packages.apps)
              bookmarks
              end_to_end_encryption
              memories
              previewgenerator
              onlyoffice
              ;
          };
          hostName = "nextcloud";
          https = true;
          configureRedis = true;
          maxUploadSize = "20G";
          database.createLocally = true;
          phpOptions = {
            "opcache.interned_strings_buffer" = "32";
          };
          caching = {
            redis = true;
            memcached = true;
          };
          config = {
            dbtype = "pgsql";
            adminuser = cfg.adminUsername;
            adminpassFile = cfg.adminPasswordFile;
          };
          settings.maintenance_window_start = 9; # 2 AM MST
          settings.default_phone_region = "US";
          settings.trusted_domains = cfg.trustedDomains;
          settings.trusted_proxies = [
            "127.0.0.1"
          ]
          ++ cfg.trustedProxies;
          settings.filelocking.enabled = true;
          settings.log_type = "file";
          settings."overwriteprotocol" = "https"; # Fix redirect after login
          settings."preview_ffmpeg_path" = "${pkgs.ffmpeg}/bin/ffmpeg";
          settings.enabledPreviewProviders = map (type: "OC\\Preview\\${type}") [
            "BMP"
            "GIF"
            "JPEG"
            "Krita"
            "MarkDown"
            "MP3"
            "OpenDocument"
            "PNG"
            "TXT"
            "XBitmap"
            "Movie"
            "MSOffice2003"
            "MSOffice2007"
            "MSOfficeDoc"
            "PDF"
            "Photoshop"
            "SVG"
            "TIFF"
            "HEIC"
          ];
        };
        services.nginx.virtualHosts."${config.services.nextcloud.hostName}".listen = [
          {
            addr = "0.0.0.0";
            port = cfg.port;
          }
        ];
      };
    };
}
