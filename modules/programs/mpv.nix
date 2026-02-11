{
  hmModule =
    {
      config,
      pkgs,
      lib,
      setMimeTypes,
      ...
    }:
    let
      inherit (lib) mkIf mkEnableOption;
      cfg = config.cfg.programs.mpv;
    in
    {
      options.cfg.programs.mpv = {
        enable = mkEnableOption "mpv";
      };

      config = mkIf cfg.enable {
        xdg.mimeApps.defaultApplications = setMimeTypes "mpv.desktop" [
          "video/mp4"
          "video/mpeg"
          "video/quicktime"
          "video/x-m4v"
          "video/x-matroska"
          "video/x-ms-wmv"
          "video/x-msvideo"
          "video/webm"
        ];

        programs.mpv = {
          enable = true;
          scripts = with pkgs.mpvScripts; [
            mpris
            uosc
            thumbfast
            autosubsync-mpv
          ];

          config = {
            vo = "gpu-next";
            hwdec = "vulkan";
            gpu-context = "auto";
            gpu-api = "vulkan";
            force-window = "yes";
            #loop-file = "inf";
            save-position-on-quit = "yes";
            keep-open = "yes";

            # uosc
            osd-bar = "no";
            border = "no";
          };

          bindings =
            let
              volume_change = x: "no-osd add volume ${x}; script-binding uosc/flash-volume";
              pause = "cycle pause; script-binding uosc/flash-pause-indicator";
              seek = x: "seek ${x}; script-binding uosc/flash-timeline";
              speed = x: "no-osd add speed ${x}; script-binding uosc/flash-speed";
            in
            {
              MOUSE_BTN0 = pause;
              MOUSE_BTN2 = "script-message-to uosc menu";

              # uosc
              WHEEL_UP = volume_change "2";
              WHEEL_DOWN = volume_change "-2";
              space = pause;
              up = volume_change "10";
              down = volume_change "-10";
              right = seek "5";
              left = seek "-5";
              "shift+right" = seek "30";
              "shift+left" = seek "-30";
              m = "no-osd cycle mute; script-binding uosc/flash-volume";
              "[" = speed "-0.25";
              "]" = speed "0.25";
              "\\" = "no-osd set speed 1; script-binding uosc/flash-speed";
            };
        };
      };
    };
}
