{
  hmModule =
    {
      pkgs,
      inputs,
      lib,
      ...
    }:
    {
      home.packages = with pkgs; [
        nodejs_latest # For ACP in Jetbrains

        # Tools for coding agents
        ripgrep
        ripgrep-all
        ast-grep
      ];

      home.file.".jetbrains/acp.json".text = builtins.toJSON {
        default_mcp_settings = {
          use_idea_mcp = true;
          use_custom_mcp = true;
        };

        agent_servers = {
          Codex = {
            command = "${lib.getExe pkgs.unstable.codex-acp}";
            args = [ ];
          };
        };
      };

      programs.codex = {
        enable = true;
        package = pkgs.unstable.codex;

        # context = ''
        #   - Available in path:rg|rga(ripgrep|ripgrep-all),ast-grep
        #   - At first check devenv.nix to see if devenv used, if not proceed normally
        #   - Use caveman lite unless told otherwise, allow it to be dropped
        #   - If dealing with system nix builds, check if there are no submodules that may make the build fail without ?submodules=1
        # '';

        # settings = {
        #   check_for_update_on_startup = false;
        #   model = "gpt-5.4";
        #   model_reasoning_effort = "medium";
        #   projects."/home/matheus".trust_level = "trusted";
        #   notice.model_migrations."gpt-5.4" = "gpt-5.5";
        # };

        skills = {
          caveman = "${inputs.caveman}/skills/caveman";
          caveman-commit = "${inputs.caveman}/skills/caveman-commit";
          caveman-review = "${inputs.caveman}/skills/caveman-review";
          caveman-compress = "${inputs.caveman}/skills/caveman-compress";
          caveman-stats = "${inputs.caveman}/skills/caveman-stats";
          caveman-help = "${inputs.caveman}/skills/caveman-help";
          cavecrew = "${inputs.caveman}/skills/cavecrew";
        };
      };
    };
}
