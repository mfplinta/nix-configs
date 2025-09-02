{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    disko.url = "github:nix-community/disko/latest";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    wrapper-manager.url = "github:viperML/wrapper-manager";
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
    hyprland.url = "github:hyprwm/Hyprland";
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
    nix-vscode-extensions.inputs.nixpkgs.follows = "nixpkgs";
    nixd.url = "github:mfplinta/nixd/7aedde58da4f5d215ff445517708f6efcf5d615f";
    nixd.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs =
    inputs@{
      self,
      nixpkgs,
      disko,
      wrapper-manager,
      chaotic,
      home-manager,
      nix-vscode-extensions,
      nix-index-database,
      nixd,
      ...
    }:
    let
      arch = "x86_64-linux";
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
          ] ++ homeManagerConfig;
        };
        "mfp-nix-laptop" = {
          modules = [
            ./targets/laptop/configuration.nix
          ] ++ homeManagerConfig;
        };
        "tiny-nix" = {
          modules = [
            ./targets/tiny/configuration.nix
          ];
        };
      };
    in
    {
      nixosConfigurations = builtins.mapAttrs (
        name: value:
        nixpkgs.lib.nixosSystem {
          system = arch;
          specialArgs = {
            inherit inputs;
            sysImport = module: (import module).sysModule;
          };
          modules = [
            disko.nixosModules.disko
            chaotic.nixosModules.nyx-cache
            chaotic.nixosModules.nyx-overlay
            chaotic.nixosModules.nyx-registry
            (
              { ... }:
              {
                nix.settings = {
                  substituters = [ "https://hyprland.cachix.org" ];
                  trusted-public-keys = [ "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=" ];
                  experimental-features = [
                    "nix-command"
                    "flakes"
                  ];
                };
                nixpkgs.config.allowUnfree = true;
                nixpkgs.hostPlatform = arch;
                nixpkgs.overlays = [
                  nix-vscode-extensions.overlays.default
                  (final: prev: {
                    nixd = prev.callPackage "${nixd}" { };
                    myScripts =
                      let
                        scripts = (import ./scripts/default.nix { pkgs = prev; });
                      in
                      {
                        toggle-scale = scripts.toggle-scale;
                        get-current-brightness = scripts.get-current-brightness;
                      };
                    cups-brother-hll3290cdw = prev.callPackage ./packages/cups-brother-hll3290cdw.nix { };
                    flat-remix-kde = prev.callPackage ./packages/flat-remix-kde.nix { };
                  })
                ];
                networking.hostName = name;
                system.stateVersion = "24.11";
              }
            )
          ] ++ value.modules;
        }
      ) systems;
    };
}
