{
  hmModule =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      inherit (lib) mkIf mkEnableOption mkOption;
      cfg = config.cfg.programs.waybar;
    in
    {
      options.cfg.programs.waybar = {
        enable = mkEnableOption "waybar";
        settings = mkOption {
          type = with lib.types; listOf anything;
        };
      };

      config = mkIf cfg.enable {
        home.packages = with pkgs; [
          nerd-fonts.droid-sans-mono
        ];
        programs.waybar = {
          enable = true;
          systemd.enable = true;
          style = builtins.readFile ./style.css;
          settings = let
            common = {
              layer = "top";
              "hyprland/workspaces".persistent-only = true;
              battery.interval = 3;
              battery.format = "{icon}󱐥 {capacity}%";
              battery.format-charging = "󱐋{icon} {capacity}%";
              battery.format-discharging = "{icon} {capacity}%";
              battery.format-icons = [ "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹" ];
              bluetooth = {
                format-on = "󰂯 On";
                format-off = "󰂯 Off";
                format-disabled = "󰂲";
                format-connected = " On ({device_alias})";
	              format-connected-battery = " ({device_alias}, {device_battery_percentage}%)";
              };
              cpu.format = " {usage}%";
              memory.format = " {percentage}%";
              disk.format = "󰋊 {percentage_used}%";
              "hyprland/language".format = "󰌌 {}";
              "hyprland/language".format-en = "US";
              "hyprland/language".format-en-intl = "US (Intl)";
              idle_inhibitor.format = "{icon}";
              idle_inhibitor.format-icons = {
                activated = "󰒳";
                deactivated = "󰒲";
              };
              network.interval = 1;
              network.format-ethernet = "󰈀 ( {bandwidthUpBytes}) ( {bandwidthDownBytes})";
              network.format-wifi = "󰖩  {bandwidthUpBytes}  {bandwidthDownBytes}";
              network.format-disconnected = "󰌙";
              network.tooltip-format-ethernet = "IP: {ipaddr}";
              network.tooltip.format-wifi = "IP: {ipaddr}\nSSID: {essid}\nStrength: {signalStrength}";
              clock = {
                format = " {:%a, %d %b %H:%M}";
                tooltip-format = "<tt><small>{calendar}</small></tt>";
                calendar = {
                  mode          = "year";
                  mode-mon-col  = 3;
                  weeks-pos     = "right";
                  on-scroll     = 1;
                  format = {
                    months =     "<span color='#ffead3'><b>{}</b></span>";
                    days =       "<span color='#ecc6d9'><b>{}</b></span>";
                    weeks =      "<span color='#99ffdd'><b>W{}</b></span>";
                    weekdays =   "<span color='#ffcc66'><b>{}</b></span>";
                    today =      "<span color='#ff6699'><b><u>{}</u></b></span>";
                  };
                };
              };
              tray.icon-size = 21;
              tray.spacing = 10;
              wireplumber.format = "{icon} {volume}%";
              wireplumber.format-icons.default = ["" ""];
              wireplumber.format-muted = "";
              wireplumber.on-click = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
              "custom/brightness" = {
                format = "{icon} {percentage}%";
                format-icons = [ "󰃞" "󰃟" "󰃠" ];
                return-type = "json";
                exec = "${lib.getExe pkgs.myScripts.get-current-brightness}";
                interval = 1;
                on-scroll-up = "brillo -e -S $(($(printf '%.0f\n' $(brillo))+5))";
                on-scroll-down = "brillo -e -S $(($(printf '%.0f\n' $(brillo))-5))";
              };
              "custom/ioperc" = {
                format = "󰒋 {percentage}%";
                return-type = "json";
                exec = "${lib.getExe pkgs.myScripts.get-current-io-util}";
                interval = 1;
              };
            };
          in
          map (cfg: common // cfg) cfg.settings;
        };
      };
    };
}
