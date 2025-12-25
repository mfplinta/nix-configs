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
    nvibrant.url = "github:mfplinta/nix-nvibrant";
    nvibrant.inputs.nixpkgs.follows = "nixpkgs";
    nixpkgs-crowdsec.url = "github:TornaxO7/nixpkgs/a4ff7e18d1440a41f4b5a75274cfac6c96df558a";
  };
  outputs =
    inputs@{
      nixpkgs,
      nixpkgs-unstable,
      nixpkgs-old,
      disko,
      wrapper-manager,
      home-manager,
      nix-index-database,
      nix-vscode-extensions,
      nixd,
      sops-nix,
      quadlet-nix,
      nvibrant,
      nixpkgs-crowdsec,
      ...
    }:
    let
      systems = {
        "mfp-nix-workstation" = {
          modules = [
            ./targets/workstation/configuration.nix
          ];
        };
        "mfp-nix-laptop" = {
          modules = [
            ./targets/laptop/configuration.nix
          ];
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
      sysImport = module: (import module).sysModule;
      hmImport = module: (import module).hmModule;

    in
    {
      nixosConfigurations = builtins.mapAttrs (
        name: value:
        nixpkgs.lib.nixosSystem {
          system = value.arch or "x86_64-linux";
          specialArgs = {
            inherit inputs sysImport;
          };
          modules = [
            disko.nixosModules.disko
            sops-nix.nixosModules.sops
            quadlet-nix.nixosModules.quadlet
            nvibrant.nixosModules.default
            home-manager.nixosModules.default
            ./private/default.nix
            (
              { config, ... }:
              {
                disabledModules = [
                  "services/security/crowdsec.nix"
                ];
                imports = [
                  "${nixpkgs-crowdsec}/nixos/modules/services/security/crowdsec.nix"
                  (sysImport ./modules)
                ];
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
                nixpkgs.overlays =
                  let
                    overlayFromInput =
                      input: overlayName:
                      (final: prev: {
                        "${overlayName}" =
                          (import input {
                            inherit (final.stdenv.hostPlatform) system;
                            inherit (final) config;
                          });
                      });
                  in
                  [
                    (import ./pkgs)
                    (overlayFromInput nixpkgs-old "nixpkgs-old")
                    (overlayFromInput nixpkgs-unstable "unstable")
                    nix-vscode-extensions.overlays.default
                    nvibrant.overlays.default
                    nixd.overlays.default
                  ];
                networking.hostName = name;
                system.stateVersion = "24.11";
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.backupFileExtension = "old-hm";
                home-manager.sharedModules = [ 
                  (hmImport ./modules)
                  quadlet-nix.homeManagerModules.quadlet
                  nix-index-database.homeModules.nix-index
                ];
                home-manager.extraSpecialArgs = {
                  inherit inputs hmImport;
                  sysConfig = config;
                  wrapper-manager = wrapper-manager;
                };
              }
            )
          ]
          ++ value.modules;
        }
      ) systems;
    };
}
