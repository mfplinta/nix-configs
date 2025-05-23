{
  hmModule =
    { pkgs, wrapper-manager, ... }:
    {
      myCfg.kdeglobals = {
        PreviewSettings."EnableRemoteFolderThumbnail" = true;
        PreviewSettings."MaximumRemoteSize" = 52428800;
        PreviewSettings."Plugins" =
          "appimagethumbnail,audiothumbnail,comicbookthumbnail,cursorthumbnail,djvuthumbnail,ebookthumbnail,exrthumbnail,directorythumbnail,imagethumbnail,jpegthumbnail,kraorathumbnail,windowsexethumbnail,windowsimagethumbnail,opendocumentthumbnail,gsthumbnail,svgthumbnail,ffmpegthumbs";
      };

      xdg = {
        mimeApps.enable = true;
        mimeApps.defaultApplications."inode/directory" = [ "org.kde.dolphin.desktop" ];
      };

      home.packages =
        with pkgs;
        with pkgs.kdePackages;
        [
          (wrapper-manager.lib.build {
            inherit pkgs;
            modules = [
              {
                wrappers.dolphin = {
                  basePackage = kdePackages.dolphin;
                  pathAdd = [
                    qtsvg
                    kio-fuse
                    kio-extras
                    kio-admin
                    ffmpegthumbs
                    kdegraphics-thumbnailers
                    qtimageformats
                  ];
                  extraWrapperFlags = ''
                    --set XDG_CONFIG_DIRS "${libsForQt5.kservice}/etc/xdg:$XDG_CONFIG_DIRS" \
                    --run '${kdePackages.kservice}/bin/kbuildsycoca6 --noincremental ${libsForQt5.kservice}/etc/xdg/menus/applications.menu'
                  '';
                };
              }
            ];
          })
        ];
    };

  sysModule =
    { pkgs, ... }:
    {
      # Nothing
    };
}
