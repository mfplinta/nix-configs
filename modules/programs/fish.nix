let
  common = pkgs: {
    enable = true;
    shellAliases = {
      ls = "${pkgs.lsd}/bin/lsd";
      tree = "${pkgs.lsd}/bin/lsd --tree";
    };
    interactiveShellInit = ''
      set fish_greeting
      set -q DIRENV_DIR; and direnv reload
      fish_add_path ~/.local/bin
    '';
  };
in
{
  hmModule =
    {
      sysConfig,
      pkgs,
      lib,
      ...
    }:
    let
      inherit (lib) mkIf;
      cfg = sysConfig.cfg.programs.fish;
    in
    {
      config = mkIf cfg.enable {
        programs.fish = lib.mkMerge [
          (common pkgs)
        ];
      };
    };

  sysModule =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      inherit (lib) mkIf mkEnableOption;
      cfg = config.cfg.programs.fish;
    in
    {
      options.cfg.programs.fish = {
        enable = mkEnableOption "fish";
      };

      config = mkIf cfg.enable {
        programs.fish = lib.mkMerge [
          (common pkgs)
        ];
      };
    };
}
