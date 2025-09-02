{
  hmModule =
    {
      pkgs,
      config,
      sysConfig,
      setMimeTypes,
      ...
    }:
    {
      warnings = pkgs.lib.mkIf (!config.fonts.fontconfig.enable) [
        "fonts.fontconfig.enable is not set. Nerd Font may not render correctly in VS Code."
      ];
      
      xdg.mimeApps.defaultApplications = setMimeTypes "code.desktop" [
        "text/plain"
        "text/x-c++src"
        "text/x-c++hdr"
        "text/x-chdr"
        "text/x-cmake"
        "text/x-csrc"
        "text/x-python"
      ];

      programs.vscode = with pkgs; {
        enable = true;
        package = vscode.override { commandLineArgs = "--password-store=kwallet6"; };
        profiles.default = {
          userSettings = {
            # General
            "update.mode" = "none";
            "extensions.ignoreRecommendations" = true;
            "extensions.autoCheckUpdates" = false;
            "extensions.autoUpdate" = false;
            "security.workspace.trust.untrustedFiles" = "open";
            "telemetry.telemetryLevel" = "off";
            "editor.selectionClipboard" = false;
            "editor.fontFamily" = "'DroidSansM Nerd Font', monospace";
            # Containers
            "containers.containerClient" = "com.microsoft.visualstudio.containers.podman";
            "dev.containers.dockerPath" = lib.getExe podman;
            "containers.containerCommand" = lib.getExe podman;
            "containers.composeCommand" = lib.getExe podman-compose;
            # Visual
            "workbench.colorTheme" = "Catppuccin Mocha";
            "workbench.iconTheme" = "material-icon-theme";
            # Nix
            "nix.enableLanguageServer" = true;
            "nix.serverPath" = lib.getExe nixd;
            "nix.serverSettings"."nixd" = {
              "formatting.command" = [ (lib.getExe nixfmt-rfc-style) ];
              "options" = {
                "nixos.expr" =
                  "(builtins.getFlake (builtins.toString ./.)).nixosConfigurations.${sysConfig.networking.hostName}.options";
                "home-manager.expr" =
                  "(builtins.getFlake (builtins.toString ./.)).nixosConfigurations.${sysConfig.networking.hostName}.options.home-manager.users.type.getSubOptions []";
              };
            };
            # C/C++
            "cmake.cmakePath" = lib.getExe cmake;
            "cmake.environment" = rec {
              PATH = "${gcc}/bin:${cmake}/bin:${coreutils}/bin:${bash}/bin:${ninja}/bin";
              LD_LIBRARY_PATH = PATH;
            };
            "C_Cpp.default.compilerPath" = "${gcc}/bin/gcc";
            # Python
            "python.analysis.typeCheckingMode" = "basic";
          };

          extensions =
            let
              ext = (forVSCodeVersion config.programs.vscode.package.version);
            in
            with ext.vscode-marketplace;
            [
              # General
              github.copilot
              #(forVSCodeVersion "1.102.0").vscode-marketplace-release.github.copilot-chat # TEMP FIX
              ext.vscode-marketplace-release.github.vscode-pull-request-github
              ms-vscode.remote-explorer
              ms-vscode-remote.remote-ssh
              ms-vscode-remote.remote-containers
              ms-azuretools.vscode-containers
              # Visual
              catppuccin.catppuccin-vsc
              pkief.material-icon-theme
              # Nix
              jnoortheen.nix-ide
              # C/C++
              ms-vscode.cpptools
              ms-vscode.cmake-tools
              ms-vscode.cpptools-themes
              # Python
              ms-python.python
              ms-python.vscode-pylance
              ms-python.debugpy
              # Web
              ritwickdey.liveserver
            ];
        };
      };

      home.packages = with pkgs; [
        nerd-fonts.droid-sans-mono
      ];
    };
}
