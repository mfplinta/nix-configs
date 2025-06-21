{
  hmModule =
    {
      pkgs,
      wrapper-manager,
      ...
    }:
    {
      home.packages = with pkgs; [
        (wrapper-manager.lib.wrapWith pkgs {
          basePackage = gparted;
          wrapperType = "shell";
          wrapFlags = [
            "--run"
            ''
              pkexec env \
              WAYLAND_DISPLAY=\"\$WAYLAND_DISPLAY\" \
              XDG_RUNTIME_DIR=\"\$XDG_RUNTIME_DIR\" \
              XDG_DATA_DIRS=\"\$XDG_DATA_DIRS\" \
              XDG_CONFIG_HOME=\"\$XDG_CONFIG_HOME\" \
              ${gparted}/libexec/gpartedbin
            ''
            "--run"
            "exit 0"
          ];
        })
      ];
    };
}
