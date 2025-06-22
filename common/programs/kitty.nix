{
  hmModule =
    { ... }:
    {
      myCfg.kdeglobals = {
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
    };
}
