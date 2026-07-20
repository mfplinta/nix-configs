let
  common =
    pkgs:
    let
      upmoveContents = pkgs.lib.getExe pkgs.myScripts.upmove;
    in
    {
      enable = true;
      shellAliases = {
        ls = "${pkgs.lsd}/bin/lsd";
        tree = "${pkgs.lsd}/bin/lsd --tree";
      };
      interactiveShellInit = ''
        set fish_greeting
        set -q DIRENV_DIR; and direnv reload
        fish_add_path ~/.local/bin

        function upmove
          set -l dir $PWD
          set -l parent (path dirname "$dir")

          if command ${upmoveContents} "$dir"
            cd "$parent"
          end
        end

        set --local hostDockerSocket /run/host/run/user/(id -u)/docker.sock
        if test -e /run/.distrobox.rootless; and test -S $hostDockerSocket
          set -gx DOCKER_HOST unix://$hostDockerSocket
        end
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
        home.packages = [ pkgs.myScripts.upmove ];
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
        environment.systemPackages = [ pkgs.myScripts.upmove ];
        programs.fish = lib.mkMerge [
          (common pkgs)
        ];
      };
    };
}
