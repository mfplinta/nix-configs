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
          plugins = {
	    cmp.enable = true;
	    cmp.autoEnableSources = true;
	    cmp.settings.sources = [
	      { name = "nvim_lsp"; }
	      { name = "path"; }
	      { name = "buffer"; }
	    ];
	    cmp.settings.mapping = {
	      "<C-Space>" = /*lua*/"cmp.mapping.complete()";
	      "<Esc>" = /*lua*/''
	        cmp.mapping(function(fallback)
		  if cmp.visible() then
		    cmp.abort()
		  else
		    fallback()
		  end
		end, {'i', 's'})
	      '';
	      "<CR>" = /*lua*/"cmp.mapping.confirm({ select = true })";
	      "<Tab>" = /*lua*/"cmp.mapping.confirm({ select = true })";
	      "<Up>" = /*lua*/"cmp.mapping(cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Select }), {'i', 's'})";
	      "<Down>" = /*lua*/"cmp.mapping(cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Select }), {'i', 's'})";
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
