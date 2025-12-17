{
  hmModule =
    { setMimeTypes, ... }:
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

      programs.brave = {
        enable = true;
        extensions = [
          { id = "cjpalhdlnbpafiamejdnhcphjbkeiagm"; } # uBlock Origin
          { id = "eimadpbcbfnmbkopoojfekhnkhdbieeh"; } # Dark Reader
          { id = "nngceckbapebfimnlniiiahkandclblb"; } # Bitwarden
          { id = "hkgfoiooedgoejojocmhlaklaeopbecg"; } # PIP
          { id = "jcbmcnpepaddcedmjdcmhbekjhbfnlff"; } # Page ruler
          { id = "fnaicdffflnofjppbagibeoednhnbjhg"; } # Floccus
          { id = "gebbhagfogifgggkldgodflihgfeippi"; } # Return YouTube Dislike
        ];
        commandLineArgs = [
          "--disable-features=AutofillSavePaymentMethods"
          "--password-store=kwallet6"
          "--disk-cache-dir=\"/tmp/BraveCache\""
          "--ozone-platform=wayland"
          "--enable-features=WaylandLinuxDrmSyncobj"
        ];
      };

      services.psd.browsers = [ "brave" ];
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
