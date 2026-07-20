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
      procps
      python3
    ];
    text = ''
      exec python3 ${./toggle-scale} "$@"
    '';
  };
  shortcut-help = writeShellApplication {
    name = "shortcut-help";
    runtimeInputs = [
      hyprland
      kitty
      python3
      tmux
    ];
    text = ''
      exec python3 ${./shortcut-help} "$@"
    '';
  };
  upmove = writeShellApplication {
    name = "upmove-contents";
    runtimeInputs = [
      coreutils
      findutils
      util-linux
    ];
    text = ''
      if (( $# > 1 )) || [[ "''${1:-}" == "--help" ]]; then
        echo "Usage: upmove-contents [DIRECTORY]" >&2
        echo "Move DIRECTORY's contents into its parent, then remove DIRECTORY." >&2
        exit $(( $# > 1 ? 2 : 0 ))
      fi

      raw_source=''${1:-"$PWD"}
      if [[ ! -d "$raw_source" ]]; then
        printf 'Not a directory: %s\n' "$raw_source" >&2
        exit 2
      fi
      if [[ -L "$raw_source" ]]; then
        printf 'Refusing symlinked source directory: %s\n' "$raw_source" >&2
        exit 2
      fi

      source_dir=$(realpath -- "$raw_source")
      parent_dir=$(dirname -- "$source_dir")
      home_dir=$(realpath -- "$HOME")

      if [[ "$source_dir" == / || "$source_dir" == "$home_dir" || "$parent_dir" == / ]]; then
        printf 'Refusing protected directory: %s\n' "$source_dir" >&2
        exit 2
      fi
      if mountpoint --quiet -- "$source_dir"; then
        printf 'Refusing mount point: %s\n' "$source_dir" >&2
        exit 2
      fi
      if [[ ! -w "$source_dir" || ! -w "$parent_dir" ]]; then
        echo "Source and parent directories must both be writable." >&2
        exit 2
      fi

      mapfile -d $'\0' -t entries < <(
        find "$source_dir" -mindepth 1 -maxdepth 1 -print0 | sort --zero-terminated
      )

      printf 'Source:      %s\n' "$source_dir"
      printf 'Destination: %s\n' "$parent_dir"
      printf 'Entries:     %d\n\n' "''${#entries[@]}"

      blocked=0
      for entry in "''${entries[@]}"; do
        name=''${entry##*/}
        destination="$parent_dir/$name"
        printf '  %q\n    -> %q\n' "$entry" "$destination"

        if [[ -e "$destination" || -L "$destination" ]]; then
          printf '    BLOCKED: destination already exists\n' >&2
          blocked=1
        elif mountpoint --quiet -- "$entry"; then
          printf '    BLOCKED: entry is a mount point\n' >&2
          blocked=1
        fi
      done

      if (( blocked != 0 )); then
        echo "No files moved. Resolve blocked entries first." >&2
        exit 1
      fi

      printf '\nThe source directory will be removed after every move succeeds.\n'
      printf 'This multi-file operation is not atomic.\n'
      read -r -p "Proceed? [y/N] " reply
      case "$reply" in
        y | Y | yes | YES) ;;
        *)
          echo "Cancelled. No files moved."
          exit 1
          ;;
      esac

      for entry in "''${entries[@]}"; do
        name=''${entry##*/}
        destination="$parent_dir/$name"
        if [[ -e "$destination" || -L "$destination" ]]; then
          printf 'Destination appeared after confirmation; stopping: %s\n' "$destination" >&2
          exit 1
        fi
        mv --no-target-directory -- "$entry" "$destination"
      done

      rmdir -- "$source_dir"
      printf 'Moved %d entries and removed %s\n' "''${#entries[@]}" "$source_dir"
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
