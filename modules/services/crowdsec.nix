# Source: https://gitlab.com/fazzi/nixohess/-/blob/main/modules/services/nvidia_oc.nix?ref_type=heads
{
  sysModule =
    {
      config,
      lib,
      ...
    }:
    let
      inherit (lib)
        mkEnableOption
        mkOption
        types
        mkIf
        ;
      cfg = config.cfg.services.crowdsec;
    in
    {
      options.cfg.services.crowdsec = {
        enable = mkEnableOption "crowdsec";
        tokenFile = mkOption {
          type = types.str;
        };
      };

      config = mkIf cfg.enable {
        services.crowdsec = {
          enable = true;
          settings = {
            general.api.server.enable = true;
            general.api.server.listen_uri = "127.0.0.1:30000";
            general.api.server.online_client.credentials_path = "/var/lib/crowdsec/online_api_credentials.yaml";
            console.tokenFile = cfg.tokenFile;
            console.configuration = {
              share_context = true;
              share_custom = true;
              share_manual_decisions = true;
              share_tainted = false;
            };
            acquisitions = [
              {
                source = "journalctl";
                journalctl_filter = [ "_SYSTEMD_UNIT=sshd.service" ];
                labels = {
                  type = "syslog";
                };
              }
            ];
          };
          hub.collections = [
            "crowdsecurity/linux"
            "crowdsecurity/sshd"
          ];
        };

        services.crowdsec-firewall-bouncer = {
          enable = true;
          registerBouncer.enable = true;
        };
      };
    };
}
