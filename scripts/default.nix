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
  get-current-io-util = writeShellApplication {
    name = "get-current-io-util";
    runtimeInputs = [ sysstat ];
    text = ''
      util=$(iostat -dx 1 2 | awk '/^nvme0n1/ {val=$NF} END{print val}')
      printf '{"percentage":%s,"tooltip":"nvme0n1 IO: %s%%"}\n' "$util" "$util"
    '';
  };
}
