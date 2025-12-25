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
      inherit (lib) mkIf mkEnableOption;
      cfg = config.cfg.programs.gparted;
    in
    {
      options.cfg.programs.gparted = {
        enable = mkEnableOption "gparted";
      };

      config = mkIf cfg.enable {
        home.packages = with pkgs; [
          (wrapper-manager.lib.wrapWith pkgs {
            basePackage = gparted;
            pathAdd = [
              e2fsprogs
              exfatprogs
              ntfs3g
              btrfs-progs
              xfsprogs
            ];
            wrapperType = "shell";
            wrapFlags = [
              "--run"
              ''
                pkexec env \
                PATH=\"\$PATH\" \
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
    };
}