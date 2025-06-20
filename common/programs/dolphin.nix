{
  hmModule =
    { pkgs, wrapper-manager, ... }:
    {
      myCfg.kdeglobals = {
        PreviewSettings."EnableRemoteFolderThumbnail" = true;
        PreviewSettings."MaximumRemoteSize" = 52428800;
        PreviewSettings."Plugins" =
          "appimagethumbnail,audiothumbnail,comicbookthumbnail,cursorthumbnail,djvuthumbnail,ebookthumbnail,exrthumbnail,directorythumbnail,imagethumbnail,jpegthumbnail,kraorathumbnail,windowsexethumbnail,windowsimagethumbnail,opendocumentthumbnail,gsthumbnail,svgthumbnail,ffmpegthumbs";
        VersionControl."enabledPlugins" = "Git";
      };

      xdg = {
        mimeApps.enable = true;
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
      };

      home.packages =
        with pkgs;
        with pkgs.kdePackages;
        [
          (wrapper-manager.lib.wrapWith pkgs {
            basePackage = kdePackages.dolphin;
            pathAdd = [
              dolphin-plugins
              qtsvg
              kio-fuse
              kio-extras
              kio-admin
              ffmpegthumbs
              kdegraphics-thumbnailers
              qtimageformats
              phonon-vlc
            ];
            wrapperType = "shell";
            wrapFlags = [
              "--prefix"
              "XDG_CONFIG_DIRS"
              ":"
              "${libsForQt5.kservice}/etc/xdg"
              "--run"
              "${kdePackages.kservice}/bin/kbuildsycoca6 --noincremental ${libsForQt5.kservice}/etc/xdg/menus/applications.menu"
            ];
          })
        ];
    };

  sysModule =
    { ... }:
    {
      # Nothing
    };
}
