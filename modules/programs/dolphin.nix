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

      dolphin =
        with pkgs;
        with pkgs.kdePackages;
        wrapper-manager.lib.wrapWith pkgs {
          basePackage = kdePackages.dolphin;
          pathAdd = [
            dolphin-plugins
            qtsvg
            kio-fuse
            kio-extras
            kio-admin
            ffmpegthumbs
            kdegraphics-thumbnailers
            kdesdk-thumbnailers
            qtimageformats
            phonon-vlc
            #libheif # Not working
          ];
          wrapperType = "shell";
          wrapFlags = [
            "--prefix"
            "XDG_CONFIG_DIRS"
            ":"
            "${kdePackages.kservice}/etc/xdg"
            "--run"
            "${kdePackages.kservice}/bin/kbuildsycoca6 --noincremental ${kdePackages.kservice}/etc/xdg/menus/applications.menu"
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
            PreviewSettings."Plugins" = "appimagethumbnail,audiothumbnail,blenderthumbnail,comicbookthumbnail,cursorthumbnail,djvuthumbnail,ebookthumbnail,exrthumbnail,directorythumbnail,pothumbnail,imagethumbnail,jpegthumbnail,kraorathumbnail,windowsexethumbnail,windowsimagethumbnail,mltpreview,mobithumbnail,opendocumentthumbnail,gsthumbnail,rawthumbnail,svgthumbnail,textthumbnail,ffmpegthumbs";
            VersionControl."enabledPlugins" = "Git";
          };
        };

        services.udiskie.settings.program_options.file_manager = "${lib.getExe' dolphin "dolphin"}";

        home.packages = [
          dolphin
          pkgs.kdePackages.ark
        ];
      };
    };
}
