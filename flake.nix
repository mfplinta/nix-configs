{
  inputs = {
    nixpkgs-old.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/master";
    disko.url = "github:nix-community/disko/latest";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    wrapper-manager.url = "github:viperML/wrapper-manager";
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
    hyprland.url = "github:hyprwm/Hyprland";
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
    nix-vscode-extensions.inputs.nixpkgs.follows = "nixpkgs";
    nixd.url = "github:mfplinta/nixd";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    quadlet-nix.url = "github:SEIAROTg/quadlet-nix";
    nvibrant.url = "gtihub:mfplinta/nix-nvibrant";
    nvibrant.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs =
    inputs@{
      self,
      nixpkgs,
      disko,
      wrapper-manager,
      home-manager,
      nix-vscode-extensions,
      nix-index-database,
      nixd,
      sops-nix,
      quadlet-nix,
      nvibrant,
      ...
    }:
    let
      homeManagerConfig = [
        home-manager.nixosModules.default
        (
          {
            config,
            lib,
            pkgs,
            ...
          }:
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "old-hm";
            home-manager.extraSpecialArgs = {
              sysConfig = config;
              hmImport =
                module:
                args@{
                  sysConfig,
                  ...
                }:
                (import module).hmModule (
                  {
                    inherit
                      config
                      lib
                      pkgs
                      inputs
                      sysConfig
                      wrapper-manager
                      ;
                    hmModule-nix-index = nix-index-database.homeModules.nix-index;
                    setMimeTypes =
                      desktopEntry: types:
                      builtins.listToAttrs (
                        map (type: {
                          name = type;
                          value = [ desktopEntry ];
                        }) types
                      );
                  }
                  // args
                );
            };
          }
        )
      ];
      systems = {
        "mfp-nix-workstation" = {
          modules = [
            ./targets/workstation/configuration.nix
          ]
          ++ homeManagerConfig;
        };
        "mfp-nix-laptop" = {
          modules = [
            ./targets/laptop/configuration.nix
          ]
          ++ homeManagerConfig;
        };
        "tiny-nix" = {
          modules = [
            ./targets/tiny/configuration.nix
          ];
        };
        "cloudy" = {
          arch = "aarch64-linux";
          modules = [
            ./targets/cloudy/configuration.nix
          ];
        };
        "gateway" = {
          modules = [
            ./targets/gateway/configuration.nix
          ];
        };
      };
    in
    {
      nixosConfigurations = builtins.mapAttrs (
        name: value:
        nixpkgs.lib.nixosSystem {
          system = value.arch or "x86_64-linux";
          specialArgs = {
            inherit inputs;
            sysImport = module: (import module).sysModule;
          };
          modules = [
            disko.nixosModules.disko
            sops-nix.nixosModules.sops
            quadlet-nix.nixosModules.quadlet
            nvibrant.nixosModules.default
            (
              { ... }:
              {
                nix.settings = {
                  substituters = [
                    "https://hyprland.cachix.org"
                    "https://devenv.cachix.org"
                  ];
                  trusted-public-keys = [
                    "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
                    "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
                  ];
                  experimental-features = [
                    "nix-command"
                    "flakes"
                  ];
                };
                nixpkgs.config = {
                  allowUnfree = true;
                  android_sdk.accept_license = true; 
                };
                nixpkgs.hostPlatform = value.arch or "x86_64-linux";
                nixpkgs.overlays = [
                  nix-vscode-extensions.overlays.default
                  nvibrant.overlays.default
                  nixd.overlays.default
                  (final: prev: rec {
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
                    cups-brother-hll3290cdw = prev.callPackage ./packages/cups-brother-hll3290cdw.nix { };
                    flat-remix-kde = prev.callPackage ./packages/flat-remix-kde.nix { };
                    django-imagekit = ps: ps.callPackage ./packages/django-imagekit.nix { };
                    django-turnstile = ps: ps.callPackage ./packages/django-turnstile.nix { };
                    profile-sync-daemon = prev.profile-sync-daemon.overrideAttrs (oldAttrs: {
                      installPhase = oldAttrs.installPhase + ''
                        mv $out/share/psd/contrib/* $out/share/psd/browsers/
                      '';
                    });
                    unstable = import inputs.nixpkgs-unstable {
                      inherit (final.stdenv.hostPlatform) system;
                      inherit (final) config;
                    };
                    stremio = (import inputs.nixpkgs-old {
                      inherit (final.stdenv.hostPlatform) system;
                      inherit (final) config;
                    }).stremio;
                    android-udev-rules = (import inputs.nixpkgs-old {
                      inherit (final.stdenv.hostPlatform) system;
                      inherit (final) config;
                    }).android-udev-rules;
                  })
                ];
                networking.hostName = name;
                system.stateVersion = "24.11";
              }
            )
          ]
          ++ value.modules;
        }
      ) systems;
    };
}
