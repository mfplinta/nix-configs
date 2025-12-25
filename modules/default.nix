{
  sysModule =
    { sysImport, ... }:
    {
      imports = [
        (sysImport ./services/django-website.nix)
        (sysImport ./services/nvidia_oc.nix)
        (sysImport ./services/vmagent.nix)
        (sysImport ./virtualisation/quadlet.nix)
      ];
    };

  hmModule =
    { hmImport, ... }:
    {
      imports = [
        (hmImport ./services/containerized/jdownloader2.nix)
      ];

      _module.args = {
        setMimeTypes =
          desktopEntry: types:
          builtins.listToAttrs (
            map (type: {
              name = type;
              value = [ desktopEntry ];
            }) types
          );
      };
    };
}
