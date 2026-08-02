{
  hmModule =
    {
      pkgs,
      wrapper-manager,
      ...
    }:
    let
      rustdeskPreLaunch = pkgs.writeShellApplication {
        name = "rustdesk-pre-launch";
        runtimeInputs = with pkgs; [
          coreutils
          procps
          systemd
        ];
        text = ''
          systemctl start rustdesk.service

          # Avoid RustDesk racing its helper and falling back to the unsupported
          # RemoteDesktop portal before the per-user server is ready.
          for _ in $(seq 1 50); do
            if pgrep -u "$UID" -f 'rustdesk.* --server' >/dev/null; then
              exit 0
            fi
            sleep 0.1
          done

          echo "RustDesk helper did not start its user server" >&2
          exit 1
        '';
      };
      rustdeskOnDemand = wrapper-manager.lib.wrapWith pkgs {
        basePackage = pkgs.rustdesk;
        wrapperType = "shell";
        wrapFlags = [
          "--run"
          (pkgs.lib.getExe rustdeskPreLaunch)
        ];
      };
      rustdeskOff = pkgs.writeShellApplication {
        name = "rustdesk-off";
        runtimeInputs = with pkgs; [
          procps
          systemd
        ];
        text = ''
          pkill -u "$UID" -f '${pkgs.rustdesk}/' || true
          systemctl stop rustdesk.service
        '';
      };
    in
    {
      cfg.programs.veracrypt.enable = true;
      cfg.programs.imhex.enable = true;
      cfg.programs.gparted.enable = true;

      home.packages = with pkgs; [
        # Utilities
        qalculate-gtk
        font-manager
        unstable.yt-dlp
        qdirstat
        rustdeskOnDemand
        rustdeskOff
      ];
    };
}
