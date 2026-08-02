{
  sysModule =
    { config, lib, ... }:
    let
      secureMode = item: builtins.match "0[46][04]0" item.mode != null;
    in
    {
      assertions = [
        {
          assertion = lib.all secureMode (
            (builtins.attrValues config.sops.secrets) ++ (builtins.attrValues config.sops.templates)
          );
          message = "SOPS secrets and templates must be owner-readable, optionally group-readable, and inaccessible to other users.";
        }
      ];
    };
}
