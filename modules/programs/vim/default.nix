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
	  enableMan = false;
          viAlias = true;
          vimAlias = true;
	  keymaps = [
	    {
	      action = "\"+y";
	      key = "<C-c>";
	      mode = "v";
	    }
	  ];
	  extraPlugins = with pkgs.vimExtraPlugins; [
            eagle-nvim
	  ];
	  extraConfigLua = ''
	    vim.o.mousemoveevent = true
	    require('eagle').setup()
	  '';
	  extraFiles."queries/yaml/injections.scm".source = ./injections.scm;
          plugins = {
	    blink-cmp.enable = true;
	    blink-cmp.settings.keymap = {
	      "<C-Space>" = [ "show" ];
	      "<Esc>" = [ "cancel" "fallback" ];
	      "<Tab>" = [ "select_and_accept" "fallback" ];
	      "<CR>" = [ "select_and_accept" "fallback" ];
	      "<Up>" = [ "select_prev" "fallback" ];
	      "<Down>" = [ "select_next" "fallback" ];
	    };
            lsp.enable = true;
            lsp.inlayHints = true;
            lsp.servers = {
              jsonls.enable = true;
              nixd.enable = true;
              yamlls.enable = true;
            };
	    treesitter.enable = true;
            treesitter.grammarPackages = with pkgs.vimPlugins.nvim-treesitter.builtGrammars; [
	      bash
	      jinja
	      jinja_inline
              json
              nix
	      python
              regex
              toml
              yaml
            ];
	    treesitter.settings = {
	      highlight.enable = true;
	      indent.enable = true;
	      indent.disable = [ "nix" ];
	      folding.enable = true;
	    };
	    lualine.enable = true;
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
