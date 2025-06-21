{
  hmModule =
    { pkgs, setMimeTypes, ... }:
    {
      xdg.mimeApps.defaultApplications = setMimeTypes "brave-browser.desktop" [
        "x-scheme-handler/http"
        "x-scheme-handler/https"
        "x-scheme-handler/ftp"
        "text/html"
        "application/x-extension-htm"
        "application/x-extension-html"
        "application/x-extension-shtml"
        "application/xhtml+xml"
        "application/x-extension-xhtml"
        "application/x-extension-xht"
      ];

      programs.chromium = {
        enable = true;
        package = pkgs.brave;
        extensions = [
          { id = "cjpalhdlnbpafiamejdnhcphjbkeiagm"; }
          { id = "eimadpbcbfnmbkopoojfekhnkhdbieeh"; }
          { id = "nngceckbapebfimnlniiiahkandclblb"; }
          { id = "hkgfoiooedgoejojocmhlaklaeopbecg"; }
        ];
        commandLineArgs = [
          "--disable-features=AutofillSavePaymentMethods"
          "--password-store=kwallet6"
          "--disk-cache-dir=\"/tmp/BraveCache\""
          "--ozone-platform=wayland"
        ];
      };
    };

  sysModule =
    { pkgs, ... }:
    {
      environment.etc."/brave/policies/managed/GroupPolicy.json".source =
        (pkgs.formats.json { }).generate "brave-GroupPolicy"
          {
            "BraveRewardsDisabled" = true;
            "BraveWalletDisabled" = true;
            "BraveVPNDisabled" = true;
            "BraveAIChatEnabled" = false;
            "DefaultSearchProviderEnabled" = true;
            "DefaultSearchProviderName" = "Google";
            "DefaultSearchProviderSearchURL" = "https://google.com/search?q={searchTerms}";
            "DefaultSearchProviderSuggestURL" =
              "https://google.com/complete/search?client=chrome&q={searchTerms}";
            "PasswordManagerEnabled" = false;
          };
    };
}
