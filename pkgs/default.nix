(final: prev: {
  myScripts =
    let
      scripts = (import ./scripts/default.nix { pkgs = prev; });
    in
    {
      toggle-scale = scripts.toggle-scale;
      get-current-brightness = scripts.get-current-brightness;
      update-website-script = scripts.update-website-script;
      get-current-io-util = scripts.get-current-io-util;
      scrcpy = scripts.scrcpy;
    };
  cups-brother-hll3290cdw = prev.callPackage ./cups-brother-hll3290cdw.nix { };
  flat-remix-kde = prev.callPackage ./flat-remix-kde.nix { };
  django-imagekit = ps: ps.callPackage ./django-imagekit.nix { };
  django-turnstile = ps: ps.callPackage ./django-turnstile.nix { };
  profile-sync-daemon = prev.profile-sync-daemon.overrideAttrs (oldAttrs: {
    installPhase = oldAttrs.installPhase + ''
      mv $out/share/psd/contrib/* $out/share/psd/browsers/
    '';
  });
})
