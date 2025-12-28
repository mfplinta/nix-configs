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
        programs.fish = {
          enable = true;
          functions = {
            fish_greeting.body = "";
          };
          shellAliases = {
            ls = "${pkgs.lsd}/bin/lsd";
            tree = "${pkgs.lsd}/bin/lsd --tree";
          };
        };
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
        programs.fish.enable = true;
        programs.fish.shellAliases = {
          ls = "${pkgs.lsd}/bin/lsd";
          tree = "${pkgs.lsd}/bin/lsd --tree";
        };
        programs.fish.interactiveShellInit = ''
          set fish_greeting
        '';
        programs.bash.interactiveShellInit = ''
          if [[ $(${pkgs.procps}/bin/ps --no-header --pid=$PPID --format=comm) != "fish" && -z ''${BASH_EXECUTION_STRING} ]]
          then
          shopt -q login_shell && LOGIN_OPTION='--login' || LOGIN_OPTION=""
          exec ${pkgs.fish}/bin/fish $LOGIN_OPTION
          fi
        '';
      };
    };
}
