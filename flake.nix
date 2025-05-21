{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixmaster.url = "github:NixOS/nixpkgs/master";
    disko.url = "github:nix-community/disko/latest";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    wrapper-manager.url = "github:viperML/wrapper-manager";
    wrapper-manager.inputs.nixpkgs.follows = "nixpkgs";
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
    hyprland.url = "github:hyprwm/Hyprland";
    hyprpanel.url = "github:Jas-SinghFSU/HyprPanel";
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
        home-manager.nixosModules.home-manager
        {
          nixpkgs.overlays = [ inputs.hyprpanel.overlay ];
        }
      ];
      nixmaster = import inputs.nixmaster {
        config.allowUnfree = true;
        system = arch;
      };
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
              {
                networking.hostName = name;
                nixpkgs.hostPlatform = arch;
                nixpkgs.overlays = [
                  (final: prev: {
                    brscan5 = nixmaster.brscan5;
                  })
                ];
              }
            ]
            ++ value.modules;
        }
      ) systems;
    };
}
