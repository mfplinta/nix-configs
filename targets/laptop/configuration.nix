let
  screenName = "eDP-1";
in
{
  inputs,
  wrapper-manager,
  pkgs,
  config,
  ...
}:
let
  sysImport = module: (import module).sysModule;
in
{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix

    (sysImport ./../../common/base.nix)
    (sysImport ./../../common/desktop.nix)
    (sysImport ./../../common/shares.nix)
    (sysImport ./../../common/containers.nix)
    (sysImport ./../../common/printing.nix)

    (sysImport ./../../common/programs/fish.nix)
    (sysImport ./../../common/programs/brave.nix)
  ];

  myCfg.westonOutput = ''
    [output]
    name=${screenName}
    mode=1920x1080@60
  '';

  boot.kernelModules = [ "msi-ec" ];
  boot.extraModulePackages = [ config.boot.kernelPackages.msi-ec ];
  boot.kernelParams = [
    "video=${screenName}:1920x1080@60"
  ];
  boot.initrd.kernelModules = [ "i915" ];

  hardware.graphics.extraPackages = with pkgs; [ vaapiIntel intel-media-driver vpl-gpu-rt ];

  networking.firewall = rec {
    allowedTCPPorts = [
      53317 # LocalSend
    ];
    allowedUDPPorts = allowedTCPPorts;
  };

  users.users.matheus = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "scanner"
      "lp"
      "video"
    ];
  };

  home-manager.users.matheus =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      hmImport =
        module:
        (import module).hmModule {
          inherit
            inputs
            pkgs
            wrapper-manager
            lib
            config
            ;
        };
    in
    {
      imports = [
        (hmImport ./../../common/base.nix)
        (hmImport ./../../common/desktop.nix)
        (hmImport ./../../common/shares.nix)

        (hmImport ./../../common/programs/fish.nix)
        (hmImport ./../../common/programs/dolphin.nix)
        (hmImport ./../../common/programs/brave.nix)
        (hmImport ./../../common/programs/mpv.nix)
        (hmImport ./../../common/programs/nomacs.nix)
      ];

      myCfg = {
        mainMonitor = screenName;

        hyprland = with lib; {
          monitor = [
            "${screenName},1920x1080@60,0x0,1"
          ];
          workspace = map (
            i: "1,monitor:${screenName},persistent:true"
          ) (range 1 9);
          general = {
            gaps_in = 5;
            gaps_out = 5;
            border_size = 2;
          };
        };

        hyprpanel.layout = {
          "bar.launcher.icon" = "";
          "bar.layouts" = {
            "0" = {
              left = [
                "cpu"
                "ram"
                "storage"
                "kbinput"
                "media"
              ];
              middle = [
                "workspaces"
              ];
              right = [
                "hypridle"
                "hyprsunset"
                "volume"
                "bluetooth"
                "systray"
                "clock"
                "notifications"
              ];
            };
          };
          "menus.clock.time.hideSeconds" = true;
          "theme.font.size" = "1rem";
        };
      };

      xdg = {
        mimeApps.enable = true;
        mimeApps.defaultApplications =
          let
            textEditor = "org.kde.kate.desktop";
            torrentClient = "org.qbittorrent.qBittorrent.desktop";
          in
          {
            "application/x-bittorrent" = [ torrentClient ];
            "application/pdf" = [ "okularApplication_pdf.desktop" ];
            "application/octet-stream" = [
              "veracrypt.desktop"
              "imhex.desktop"
              textEditor
            ];
            "text/plain" = [ textEditor ];
            "x-scheme-handler/magnet" = [ torrentClient ];
          };
      };

      home.packages =
        with pkgs;
        with pkgs.kdePackages;
        [
          kate
          okular
          ark
          veracrypt
          imhex
          qalculate-gtk

          # Internet
          qbittorrent
          localsend

          # Media
          moonlight-qt
          anydesk

          # Office
          simple-scan
          onlyoffice-desktopeditors
        ];

      home.stateVersion = "24.11";
    };

  system.stateVersion = "24.11";
}
