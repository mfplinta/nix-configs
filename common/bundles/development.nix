{
  hmModule =
    { pkgs, lib, hmImport, ... }:
    {
      imports = [
        (hmImport ./../programs/kate.nix)
        (hmImport ./../programs/vscode.nix)
      ];

      home.packages = with pkgs; [
        jetbrains.pycharm-professional
        inkscape
        devenv
      ];

      home.activation.createCopilotSymlink = lib.hm.dag.entryAfter ["writeBoundary"] ''
        run ln -sfn ${pkgs.github-copilot-intellij-agent}/bin/copilot-agent /home/matheus/.local/share/JetBrains/PyCharm2025.1/github-copilot-intellij/copilot-agent/native/linux-x64/copilot-language-server
      '';
    };
}
