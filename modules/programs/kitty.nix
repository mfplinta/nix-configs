{
  hmModule =
    { config, lib, ... }:
    let
      inherit (lib) mkIf mkEnableOption mkDefault;
      cfg = config.cfg.programs.kitty;
    in
    {
      options.cfg.programs.kitty = {
        enable = mkEnableOption "kitty";
      };

      config = mkIf cfg.enable {
        cfg.kdeglobals = {
          General."TerminalApplication" = "kitty";
          General."TerminalService" = "kitty.desktop";
        };

        programs.kitty = {
          enable = true;
          shellIntegration.enableFishIntegration = true;
          settings = {
            font_size = 15;
            background_opacity = 0.8;
            confirm_os_window_close = -1;
          };
        };

        xdg.terminal-exec.enable = mkDefault true;
        xdg.terminal-exec.settings.default = [
          "kitty.desktop"
        ];
      };
    };
}
