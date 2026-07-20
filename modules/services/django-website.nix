{
  sysModule =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      inherit (lib)
        mkEnableOption
        mkIf
        mkOption
        optional
        optionalAttrs
        optionalString
        types
        ;

      cfg = config.cfg.services.django-website;
      statePath = "/var/lib/${cfg.stateDirectory}";
      deploymentModule = "${cfg.appName}_deployment";

      deploymentSettings = pkgs.runCommand "${cfg.appName}-deployment-settings" { } ''
        mkdir -p "$out/${deploymentModule}"
        touch "$out/${deploymentModule}/__init__.py"
        cat > "$out/${deploymentModule}/settings.py" <<'PY'
        from ${cfg.appName}.settings import *  # noqa: F401,F403
        import os
        from pathlib import Path

        STATE_DIRECTORY = Path(os.environ["DJANGO_STATE_DIRECTORY"])

        DATABASES = dict(DATABASES)
        DATABASES["default"] = dict(DATABASES["default"])
        DATABASES["default"]["NAME"] = STATE_DIRECTORY / "db.sqlite3"

        STATIC_ROOT = STATE_DIRECTORY / "staticfiles"
        STATIC_URL = "/static/"
        MEDIA_ROOT = STATE_DIRECTORY / "media"
        MEDIA_URL = "/media/"

        DEBUG = False
        CSRF_COOKIE_SECURE = True
        SESSION_COOKIE_SECURE = True
        SECURE_CONTENT_TYPE_NOSNIFF = True
        SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
        FILE_UPLOAD_PERMISSIONS = 0o644
        FILE_UPLOAD_DIRECTORY_PERMISSIONS = 0o755
        PY
      '';

      djangoEnvironment = pkgs.python3.withPackages (
        pythonPackages:
        with pythonPackages;
        [
          django
          django-markdownx
          gunicorn
          pillow
          whitenoise
          (pkgs.django-imagekit pythonPackages)
        ]
        ++ cfg.extraPythonPackages pythonPackages
      );

      serviceEnvironment = {
        DJANGO_DEBUG = "False";
        DJANGO_SETTINGS_MODULE = "${deploymentModule}.settings";
        DJANGO_STATE_DIRECTORY = statePath;
        PYTHONPATH = "${deploymentSettings}:${cfg.source}";
      };

      commonServiceConfig = {
        User = "django";
        Group = "django";
        WorkingDirectory = cfg.source;
        StateDirectory = cfg.stateDirectory;
        StateDirectoryMode = "0711";
        UMask = "0077";

        CapabilityBoundingSet = "";
        LockPersonality = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProcSubset = "pid";
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectProc = "invisible";
        ProtectSystem = "strict";
        ReadWritePaths = [ statePath ];
        RemoveIPC = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [ "@system-service" ];
      }
      // optionalAttrs (cfg.envFile != null) {
        EnvironmentFile = cfg.envFile;
      };

      manage = "${djangoEnvironment}/bin/python ${cfg.source}/manage.py";
      prepareUnit = "django-website-prepare.service";
      migrateUnit = "django-website-migrate.service";

      deploymentCheck = pkgs.runCommand "${cfg.appName}-django-deployment-check" { } ''
        export DJANGO_DEBUG=False
        export DJANGO_SETTINGS_MODULE=${serviceEnvironment.DJANGO_SETTINGS_MODULE}
        export DJANGO_STATE_DIRECTORY="$TMPDIR/state"
        export PYTHONPATH=${serviceEnvironment.PYTHONPATH}
        export SECRET_KEY=build-time-validation-key-not-used-at-runtime-0123456789abcdef
        export TURNSTILE_SITEKEY=build-time-validation
        export TURNSTILE_SECRET=build-time-validation

        mkdir -p "$DJANGO_STATE_DIRECTORY"
        ${manage} check --deploy --fail-level ERROR
        ${optionalString cfg.validateMigrations "${manage} migrate --plan --noinput"}
        ${manage} collectstatic --noinput --verbosity 0
        touch "$out"
      '';
    in
    {
      options.cfg.services.django-website = {
        enable = mkEnableOption "immutable Django website";

        source = mkOption {
          type = types.path;
          description = "Immutable Django source, normally a locked non-flake input.";
        };

        appName = mkOption {
          type = types.strMatching "[A-Za-z_][A-Za-z0-9_]*";
          description = "Python package containing the Django settings and WSGI modules.";
        };

        envFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = "Runtime environment file containing Django secrets.";
        };

        extraPythonPackages = mkOption {
          type = types.functionTo (types.listOf types.package);
          default = _: [ ];
          description = "Function selecting additional packages from python3Packages.";
        };

        stateDirectory = mkOption {
          type = types.strMatching "[A-Za-z0-9_.-]+";
          default = "django-website";
          description = "Directory below /var/lib containing the database, media, and collected static files.";
        };

        bindAddress = mkOption {
          type = types.str;
          default = "127.0.0.1";
          description = "Gunicorn listen address.";
        };

        port = mkOption {
          type = types.port;
          default = 9000;
          description = "Gunicorn listen port.";
        };

        frontendPort = mkOption {
          type = types.port;
          default = 8000;
          description = "Caddy listen port.";
        };

        workers = mkOption {
          type = types.ints.positive;
          default = 3;
          description = "Number of Gunicorn workers.";
        };

        runMigrationsOnStart = mkOption {
          type = types.bool;
          default = false;
          description = "Run migrations before Gunicorn. Leave disabled until application migration history is complete and reviewed.";
        };

        validateMigrations = mkOption {
          type = types.bool;
          default = true;
          description = "Validate the migration graph during every system build.";
        };
      };

      config = mkIf cfg.enable {
        assertions = [
          {
            assertion = builtins.pathExists "${cfg.source}/manage.py";
            message = "Django source must contain manage.py at its root.";
          }
          {
            assertion = builtins.pathExists "${cfg.source}/${cfg.appName}/wsgi.py";
            message = "Django source must contain ${cfg.appName}/wsgi.py.";
          }
          {
            assertion = !cfg.runMigrationsOnStart || cfg.validateMigrations;
            message = "Automatic Django migrations require build-time migration validation.";
          }
        ];

        system.extraDependencies = [ deploymentCheck ];

        services.caddy = {
          enable = true;
          configFile = pkgs.writeText "Caddyfile-${cfg.appName}" ''
            :${toString cfg.frontendPort} {
              encode gzip

              handle_path /media/* {
                root * ${statePath}/media
                file_server
              }

              handle {
                reverse_proxy ${cfg.bindAddress}:${toString cfg.port}
              }
            }
          '';
        };

        systemd.tmpfiles.rules = [
          "d ${statePath} 0711 django django -"
          "d ${statePath}/media 0755 django django -"
          "d ${statePath}/staticfiles 0700 django django -"
          "z ${statePath}/db.sqlite3 0600 django django -"
        ];

        systemd.services = {
          django-website-prepare = {
            description = "Validate and collect static files for ${cfg.appName}";
            before = [ "django-gunicorn.service" ];
            environment = serviceEnvironment;
            serviceConfig = commonServiceConfig // {
              Type = "oneshot";
              ExecStart = pkgs.writeShellScript "prepare-${cfg.appName}" ''
                set -eu
                ${manage} check --deploy --fail-level ERROR
                ${manage} collectstatic --noinput
              '';
            };
          };

          django-website-migrate = {
            description = "Apply reviewed database migrations for ${cfg.appName}";
            before = [ "django-gunicorn.service" ];
            environment = serviceEnvironment;
            serviceConfig = commonServiceConfig // {
              Type = "oneshot";
              ExecStart = "${manage} migrate --noinput";
            };
          };

          django-gunicorn = {
            description = "Gunicorn for ${cfg.appName}";
            after = [
              "network.target"
              prepareUnit
            ]
            ++ optional cfg.runMigrationsOnStart migrateUnit;
            requires = [ prepareUnit ] ++ optional cfg.runMigrationsOnStart migrateUnit;
            wantedBy = [ "multi-user.target" ];
            environment = serviceEnvironment;
            serviceConfig = commonServiceConfig // {
              Type = "simple";
              ExecStart = "${djangoEnvironment}/bin/gunicorn --workers ${toString cfg.workers} --bind ${cfg.bindAddress}:${toString cfg.port} --access-logfile - --error-logfile - ${cfg.appName}.wsgi:application";
              Restart = "on-failure";
              RestartSec = "5s";
              TimeoutStopSec = "30s";
            };
          };
        };

        users.users.django = {
          isSystemUser = true;
          group = "django";
        };
        users.groups.django = { };
      };
    };
}
