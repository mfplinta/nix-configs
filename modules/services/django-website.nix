{
  sysModule = { pkgs, lib, config, ... }:
  let
    inherit (lib) mkEnableOption mkOption types mkIf;
    cfg = config.cfg.services.django-website;
    caddy-django-env =
      with pkgs.python3Packages;
      with pkgs;
      python3.withPackages (
        ps: with ps; [
          django
          gunicorn
          pillow
          django-markdownx
          whitenoise
          (django-imagekit ps)
          (django-turnstile ps)
        ]
      );
  in
  {
    options.cfg.services.django-website = {
      enable = mkEnableOption "django-website";
      appName = mkOption {
        type = types.str;
        default = "website";
        description = "The name of the Django application.";
      };
      envFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to the environment file for Django settings.";
      };
    };

    config = mkIf cfg.enable {
      environment.systemPackages = with pkgs; [
        (writeShellApplication {
          name = "update-website";
          runtimeInputs = [
            git
            caddy-django-env
          ];
          text = ''
            set -e
            set -x
            cd /app/

            if [ "$USER" = "django" ]
            then
              git pull
              python manage.py collectstatic --noinput
            elif [ "$USER" = "root" ]
            then
              git config --global --add safe.directory '*'
              chown -R django:django .
              sudo -u django "$0" "$@"
              systemctl restart django-gunicorn.service
            else
              echo "Please run as sudo or django"
              exit 1
            fi
          '';
        })
      ];

      services.caddy = {
        enable = true;
        configFile = pkgs.writeText "Caddyfile" ''
          :8000 {
            encode gzip

            handle_path /media/* {
              root * /app/media
              file_server
            }

            handle {
              reverse_proxy 127.0.0.1:9000
            }
          }
        '';
      };

      systemd.tmpfiles.rules = [
        "d /app 0755 django django -"
      ];

      systemd.services.django-gunicorn = {
        description = "Gunicorn service for Django app";
        after = [
          "network.target"
          "systemd-tmpfiles-setup.service"
        ];
        wantedBy = [ "multi-user.target" ];
        environment.DJANGO_DEBUG = "False";
        serviceConfig = {
          Type = "simple";
          User = "django";
          Group = "django";
          WorkingDirectory = "/app";
          EnvironmentFile = mkIf (cfg.envFile != null) [ cfg.envFile ];
          ExecStart = "${caddy-django-env}/bin/gunicorn --workers 3 --bind 127.0.0.1:9000 ${cfg.appName}.wsgi:application";
          Restart = "always";
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