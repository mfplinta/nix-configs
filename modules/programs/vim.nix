{
  sysModule = { pkgs, config, lib, nixvim, ... }:
  let
    inherit (lib) mkEnableOption mkOption mkIf;
    cfg = config.cfg.programs.vim;
  in
  {
    options.cfg.programs.vim = {
      enable = mkEnableOption "vim";
      useBasicVim = mkOption {
        type = lib.types.bool;
        default = false;
        description = "Use a basic vim build without LSP and colorschemes.";
      };
    };

    config = mkIf cfg.enable {
      environment.sessionVariables.EDITOR = "vim";
      environment.systemPackages = [
        (mkIf (!cfg.useBasicVim) (nixvim.legacyPackages."${pkgs.stdenv.hostPlatform.system}".makeNixvim {
          viAlias = true;
          vimAlias = true;
          plugins = {
            lsp.enable = true;
            lsp.inlayHints = true;
            lsp.servers = {
              jsonls.enable = true;
              nixd.enable = true;
              yamlls.enable = true;
            };
          };
          colorschemes.catppuccin = {
            enable = true;
            settings.flavour = "mocha";
          };
        }))
        (mkIf (cfg.useBasicVim) pkgs.vim)
      ];
    };
  };
}