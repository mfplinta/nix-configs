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
      cfg = config.cfg.programs.dolphin;

      kdeRuntimePackages =
        with pkgs;
        with kdePackages;
        [
          dolphin-plugins
          qtsvg
          kio
          kio-fuse
          kio-extras
          kio-admin
          calligra
          ffmpegthumbs
          kdegraphics-thumbnailers
          kdesdk-thumbnailers
          kimageformats
          qtimageformats
          phonon-vlc
          resvg
        ];

      dolphin =
        with pkgs;
        with pkgs.kdePackages;
        let
          plasmaMenu = "${plasma-workspace}/etc/xdg/menus/plasma-applications.menu";
        in
        wrapper-manager.lib.wrapWith pkgs {
          basePackage = kdePackages.dolphin;
          pathAdd = kdeRuntimePackages;
          wrapperType = "shell";
          wrapFlags = [
            "--prefix"
            "XDG_CONFIG_DIRS"
            ":"
            "${plasma-workspace}/etc/xdg"
            "--prefix"
            "XDG_DATA_DIRS"
            ":"
            (lib.makeSearchPath "share" ([ plasma-workspace ] ++ kdeRuntimePackages))
            "--prefix"
            "QT_PLUGIN_PATH"
            ":"
            (lib.makeSearchPath "lib/qt-6/plugins" kdeRuntimePackages)
            "--set"
            "XDG_MENU_PREFIX"
            "plasma-"
            "--run"
            "${kdePackages.kservice}/bin/kbuildsycoca6 --noincremental ${plasmaMenu}"
          ];
        };
    in
    {
      options.cfg.programs.dolphin = {
        enable = mkEnableOption "dolphin";
      };

      config = mkIf cfg.enable {
        cfg.kdeglobals = {
          PreviewSettings."EnableRemoteFolderThumbnail" = true;
          PreviewSettings."MaximumRemoteSize" = 52428800;
        };

        xdg = {
          mimeApps.defaultApplications."inode/directory" = [ "org.kde.dolphin.desktop" ];
          configFile."kservicemenurc".source = (pkgs.formats.ini { }).generate "kservicemenurc" {
            Show = {
              compressfileitemaction = true;
              extractfileitemaction = true;
              forgetfileitemaction = true;
              kactivitymanagerd_fileitem_linking_plugin = false;
              kdeconnectfileitemaction = true;
              kio-admin = true;
              makefileactions = true;
              mountisoaction = true;
              movetonewfolderitemaction = true;
              tagsfileitemaction = false;
            };
          };
          configFile."dolphinrc".source = (pkgs.formats.ini { }).generate "dolphinrc" {
            PreviewSettings."Plugins" =
              "appimagethumbnail,audiothumbnail,blenderthumbnail,calligraimagethumbnail,calligrathumbnail,comicbookthumbnail,cursorthumbnail,djvuthumbnail,ebookthumbnail,exrthumbnail,directorythumbnail,pothumbnail,imagethumbnail,jpegthumbnail,kraorathumbnail,windowsexethumbnail,windowsimagethumbnail,mltpreview,mobithumbnail,gsthumbnail,rawthumbnail,svgthumbnail,textthumbnail,ffmpegthumbs";
            VersionControl."enabledPlugins" = "Git";
          };
        };

        services.udiskie.settings.program_options.file_manager = "${lib.getExe' dolphin "dolphin"}";

        home.packages = [
          dolphin
          pkgs.kdePackages.ark
          pkgs.kdePackages.kio-extras
        ];
      };
    };
}
