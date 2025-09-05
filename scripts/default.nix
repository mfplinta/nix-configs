{pkgs, ...}:
with pkgs;
{
  toggle-scale = writeShellApplication {
    name = "toggle-scale";
    runtimeInputs = [ hyprland python3 ];
    text = ''
      exec python3 ${./toggle-scale} "$@"
    '';
  };
  get-current-brightness = writeShellApplication {
    name = "get-current-brightness";
    runtimeInputs = [ brillo ];
    text = ''
      echo -n '{"tooltip": "'
      brillo -L | while read -r dev; do
        pct=$(brillo -s "$dev" -G)
        printf "%s: %.2f%%\\\n" "$dev" "$pct"
      done | sed '$s/\\n$//'
      echo -n '", "percentage": '"$(brillo)"'}'
    '';
  };
  update-website-script = writeShellApplication {
    name = "update-website";
    runtimeInputs = [ git ];
    text = ''
      set -e
      set -x

      if [ -f manage.py ] && [ -d .git ]; then
          git config --global --add safe.directory '*'
          git pull
          ${lib.getExe caddy-django-env} manage.py collectstatic --noinput
          systemctl restart django-gunicorn.service
      else
          echo "manage.py or .git not found in current dir"
      fi
    '';
  };
}