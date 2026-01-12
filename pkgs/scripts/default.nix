{ pkgs, ... }:
let
  launcherPackage = pkgs.wofi;
in
with pkgs;
{
  toggle-scale = writeShellApplication {
    name = "toggle-scale";
    runtimeInputs = [
      hyprland
      python3
    ];
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
  scrcpy = writeShellApplication {
    name = "scrcpy";
    runtimeInputs = [
      scrcpy
      android-tools
      launcherPackage
    ];
    text = ''
      adb devices | awk 'NR>1 && $2=="device" {print $1}' | ${lib.getExe launcherPackage} --dmenu -p "Select device" | xargs -r -I{} scrcpy -s {} -SwK --render-driver=opengl
    '';
  };
  rebuild = writeShellApplication {
    name = "rebuild";
    runtimeInputs = [
      python3
      bash
    ];
    text = ''
      exec python3 ${./rebuild} "$@"
    '';
  };
  wpctl-cycle = writeShellApplication {
    name = "next-sink";
    runtimeInputs = [
      wireplumber
    ];
    text = builtins.readFile ./wpctl-cycle;
  };
}
