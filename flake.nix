{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixmaster.url = "github:NixOS/nixpkgs/master";
    disko.url = "github:nix-community/disko/latest";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    wrapper-manager.url = "github:viperML/wrapper-manager";
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
    hyprland.url = "github:hyprwm/Hyprland";
    hyprpanel.url = "github:Jas-SinghFSU/HyprPanel";
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
    nix-vscode-extensions.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs =
    inputs@{
      self,
      nixpkgs,
      nixmaster,
      disko,
      wrapper-manager,
      chaotic,
      home-manager,
      hyprpanel,
      nix-vscode-extensions,
      ...
    }:
    let
      systems = {
        "mfp-nix-workstation" = {
          modules = [ ./targets/workstation/configuration.nix ];
        };
        "mfp-nix-laptop" = {
          modules = [ ./targets/laptop/configuration.nix ];
        };
      };
      arch = "x86_64-linux";
      commonModules = [
        disko.nixosModules.disko
        chaotic.nixosModules.nyx-cache
        chaotic.nixosModules.nyx-overlay
        chaotic.nixosModules.nyx-registry
        
      ];
#       nixmaster = import inputs.nixmaster {
#         config.allowUnfree = true;
#         system = arch;
#       };
    in
    {
      nixosConfigurations = builtins.mapAttrs (
        name: value:
        nixpkgs.lib.nixosSystem {
          system = arch;
          specialArgs = { inherit inputs wrapper-manager; };
          modules =
            commonModules
            ++ [
              home-manager.nixosModules.default {
                home-manager.extraSpecialArgs = {
                  hostName = name;
                };
              }
              {
                networking.hostName = name;
                nixpkgs.hostPlatform = arch;
                nixpkgs.overlays = [
                  nix-vscode-extensions.overlays.default
                  hyprpanel.overlay
                  (final: prev: {
                    # Ex: brscan5 = nixmaster.brscan5;
                  })
                ];
              }
            ]
            ++ value.modules;
        }
      ) systems;
    };
}
