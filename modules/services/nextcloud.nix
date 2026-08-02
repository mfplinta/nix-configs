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
      runtimeLogrotateConfig = "/run/logrotate-nextcloud.conf";
      onlyofficeSecretDir = "/run/nextcloud-service-secrets";
      prepareLogrotateConfig = pkgs.writeShellScript "prepare-logrotate-config" ''
        ${pkgs.coreutils}/bin/install -m 0600 ${config.services.logrotate.configFile} ${runtimeLogrotateConfig}
      '';
      prepareOnlyofficeSecrets = pkgs.writeShellScript "prepare-onlyoffice-secrets" ''
        ${pkgs.coreutils}/bin/chown root:onlyoffice ${onlyofficeSecretDir}
        ${pkgs.coreutils}/bin/install -m 0400 -o onlyoffice -g onlyoffice \
          ${cfg.onlyoffice.jwtSecretFile} ${onlyofficeSecretDir}/jwt
        ${pkgs.coreutils}/bin/install -m 0440 -o onlyoffice -g onlyoffice \
          ${cfg.onlyoffice.securityNonceFile} ${onlyofficeSecretDir}/nonce.conf
      '';
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
        externalUrl = mkOption {
          type = types.str;
          example = "https://nextcloud.example.com";
          description = "Canonical URL used by Nextcloud background jobs and integrations.";
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
          package = pkgs.unstable.onlyoffice-documentserver;
          x2t = pkgs.unstable.onlyoffice-documentserver.x2t;
          jwtSecretFile = "${onlyofficeSecretDir}/jwt";
          securityNonceFile = "${onlyofficeSecretDir}/nonce.conf";
        };

        services.nginx.virtualHosts."${config.services.onlyoffice.hostname}" = {
          listen = [
            {
              addr = "0.0.0.0";
              port = cfg.onlyoffice.port;
            }
          ];

          # TLS terminates at the external reverse proxy, so $scheme is HTTP
          # on this internal hop even though the public request uses HTTPS.
          extraConfig = lib.mkForce ''
            rewrite ^/$ /welcome/ redirect;
            rewrite ^\/OfficeWeb(\/apps\/.*)$ /${config.services.onlyoffice.package.version}/web-apps$1 redirect;
            rewrite ^(\/web-apps\/apps\/(?!api\/).*)$ /${config.services.onlyoffice.package.version}$1 redirect;

            proxy_set_header Host $host;
            proxy_set_header X-Forwarded-Host $host;
            proxy_set_header X-Forwarded-Proto https;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection $connection_upgrade;
          '';
        };

        services.nextcloud = {
          enable = true;
          package = pkgs.unstable.nextcloud34;
          extraAppsEnable = true;
          extraApps = {
            inherit (pkgs.unstable.nextcloud34.packages.apps)
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
          settings."overwrite.cli.url" = cfg.externalUrl;
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

        systemd.services.logrotate.serviceConfig = {
          ExecStartPre = [ prepareLogrotateConfig ];
          ExecStart = lib.mkForce "${pkgs.logrotate}/sbin/logrotate ${runtimeLogrotateConfig}";
        };
        systemd.services.logrotate-checkconf.serviceConfig = {
          ExecStartPre = [ prepareLogrotateConfig ];
          ExecStart = lib.mkForce "${pkgs.logrotate}/sbin/logrotate --debug ${runtimeLogrotateConfig}";
        };
        systemd.services.prepare-onlyoffice-secrets = {
          requiredBy = [
            "nginx.service"
            "onlyoffice-docservice.service"
          ];
          before = [
            "nginx.service"
            "onlyoffice-docservice.service"
          ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            RuntimeDirectory = "nextcloud-service-secrets";
            RuntimeDirectoryMode = "0750";
            ExecStart = prepareOnlyofficeSecrets;
          };
        };
      };
    };
}
