{
  hmModule =
    {
      pkgs,
      inputs,
      lib,
      mkMutableGeneratedFile,
      private,
      ...
    }:
    let
      codexContext = pkgs.writeText "codex-AGENTS.md" ''
        - Available in path: rg(ripgrep),rga(ripgrep-all),ast-grep,node,jq,file
        - If requiring sudo for any operation, spawn a new instance of the default terminal that asks for sudo and ensures it doesn't leak the password into the model's chat/context
        - At first check devenv.nix to see if devenv used, if not proceed normally
        - Use caveman lite unless told otherwise, allow it to be dropped
        - If files are showing as not tracked in Nix, check if they are defined in `git submodules`
      '';

      codexConfig = (pkgs.formats.toml { }).generate "codex-config.toml" {
        check_for_update_on_startup = false;
        service_tier = "default";
        model = "gpt-5.6-sol";
        model_reasoning_effort = "medium";
        approval_policy = "on-request";
        approvals_reviewer = "auto_review";

        tui = {
          status_line = [
            "model-with-reasoning"
            "current-dir"
            "context-used"
            "five-hour-limit"
            "weekly-limit"
          ];
          status_line_use_colors = true;
          model_availability_nux = {
            "gpt-5.5" = 4;
            "gpt-5.6-sol" = 4;
          };
        };

        notice.model_migrations."gpt-5.4" = "gpt-5.5";

        mcp_servers.playwright = {
          command = lib.getExe pkgs.playwright-mcp;
          default_tools_approval_mode = "approve";
          args = [
            "--headless"
            "--isolated"
            "--no-sandbox"
            "--executable-path"
            (lib.getExe pkgs.google-chrome)
          ];
        };
      };
    in
    {
      home.packages = with pkgs; [
        nodejs_latest # For ACP in Jetbrains

        # Tools for coding agents
        ripgrep
        ripgrep-all
        ast-grep
        file
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

        skills = {
          caveman = "${inputs.caveman}/skills/caveman";
          caveman-commit = "${inputs.caveman}/skills/caveman-commit";
          caveman-review = "${inputs.caveman}/skills/caveman-review";
          caveman-compress = "${inputs.caveman}/skills/caveman-compress";
          caveman-stats = "${inputs.caveman}/skills/caveman-stats";
          caveman-help = "${inputs.caveman}/skills/caveman-help";
          cavecrew = "${inputs.caveman}/skills/cavecrew";
          humanizer = "${inputs.humanizer}";
        }
        // private.ai_skills;
      };

      home.activation.installMutableCodexConfig = mkMutableGeneratedFile {
        source = codexConfig;
        target = ".codex/config.toml";
      };

      home.activation.installMutableCodexContext = mkMutableGeneratedFile {
        source = codexContext;
        target = ".codex/AGENTS.md";
      };
    };
}
