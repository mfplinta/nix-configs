{
  hmModule =
    {
      config,
      pkgs,
      lib,
      wrapper-manager,
      ...
    }:
    let
      inherit (lib) mkEnableOption mkIf;
      cfg = config.cfg.programs.gparted;
    in
    {
      options.cfg.programs.gparted.enable = mkEnableOption "gparted";

      config = mkIf cfg.enable {
        home.packages = [
          (wrapper-manager.lib.wrapWith pkgs {
            basePackage = pkgs.gparted-full;
            wrapperType = "shell";
            wrapFlags = [
              "--run"
              ''
                pkexec env \
                  WAYLAND_DISPLAY=\"\$WAYLAND_DISPLAY\" \
                  XDG_RUNTIME_DIR=\"\$XDG_RUNTIME_DIR\" \
                  XDG_DATA_DIRS=\"\$XDG_DATA_DIRS\" \
                  XDG_CONFIG_HOME=\"\$XDG_CONFIG_HOME\" \
                  ${pkgs.gparted-full}/libexec/gpartedbin
              ''
              "--run"
              "exit 0"
            ];
          })
        ];
      };
    };
}
