# Source: https://gitlab.com/fazzi/nixohess/-/blob/main/modules/services/nvidia_oc.nix?ref_type=heads
{
  sysModule =
    {
      config,
      lib,
      pkgs,
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
        port = mkOption {
          type = types.port;
          default = 30000;
        };
        modules.sshd.enable = mkEnableOption "crowdsec sshd";
        modules.sshd.apiKeyFile = mkOption {
          type = types.path;
        };
        modules.caddy.enable = mkEnableOption "crowdsec caddy";
        modules.caddy.logfile = mkOption {
          type = types.str;
        };
        modules.caddy.apiKeyFile = mkOption {
          type = types.path;
        };
      };

      config = mkIf cfg.enable {
        services.crowdsec = {
          enable = true;
          settings = {
            general.api.server.enable = true;
            general.api.server.listen_uri = "0.0.0.0:${toString cfg.port}";
            general.api.server.online_client.credentials_path = "/var/lib/crowdsec/online_api_credentials.yaml";
            console.tokenFile = cfg.tokenFile;
            console.configuration = {
              share_context = true;
              share_custom = true;
              share_manual_decisions = true;
              share_tainted = false;
            };
            acquisitions = [
              (mkIf cfg.modules.sshd.enable {
                source = "journalctl";
                journalctl_filter = [ "_SYSTEMD_UNIT=sshd.service" ];
                labels = {
                  type = "syslog";
                };
              })
              (mkIf cfg.modules.caddy.enable {
                filename = cfg.modules.caddy.logfile;
                labels = {
                  type = "caddy";
                };
              })
            ];
          };
          hub.collections = [
            "crowdsecurity/linux"
            "crowdsecurity/sshd"
          ]
          ++ lib.optionals cfg.modules.caddy.enable [
            "crowdsecurity/caddy"
            "crowdsecurity/appsec-virtual-patching"
            "crowdsecurity/appsec-generic-rules"
          ];
        };

        services.crowdsec-firewall-bouncer = rec {
          enable = cfg.modules.sshd.enable;
          registerBouncer.enable = false;
          secrets.apiKeyPath = cfg.modules.sshd.apiKeyFile;
        };

        systemd.services =
          let
            serviceName = "crowdsec-bouncers-register";
            sshdBouncer = "crowdsec-firewall-bouncer";
            caddyBouncer = "crowdsec-caddy-bouncer";
          in
          {
            "${serviceName}" = lib.mkIf cfg.modules.caddy.enable rec {
              description = "Register the CrowdSec bouncers to the local CrowdSec service";
              wantedBy = [ "multi-user.target" ];
              after = [ "crowdsec.service" ];
              wants = after;
              script = ''
                cscli=/run/current-system/sw/bin/cscli
                $cscli bouncers delete ${sshdBouncer} || true
                $cscli bouncers delete ${caddyBouncer} || true
                $cscli bouncers add ${sshdBouncer} -k $(cat ${cfg.modules.sshd.apiKeyFile})
                $cscli bouncers add ${caddyBouncer} -k $(cat ${cfg.modules.caddy.apiKeyFile})
              '';
              serviceConfig = {
                Type = "oneshot";

                # Run as crowdsec user to be able to use cscli
                User = config.services.crowdsec.user;
                Group = config.services.crowdsec.group;

                StateDirectory = "${serviceName}";

                ReadWritePaths = [
                  # Needs write permissions to add the bouncer
                  "/var/lib/crowdsec"
                ];

                DynamicUser = true;
                LockPersonality = true;
                PrivateDevices = true;
                ProcSubset = "pid";
                ProtectClock = true;
                ProtectControlGroups = true;
                ProtectHome = true;
                ProtectHostname = true;
                ProtectKernelLogs = true;
                ProtectKernelModules = true;
                ProtectKernelTunables = true;
                ProtectProc = "invisible";
                RestrictNamespaces = true;
                RestrictRealtime = true;
                SystemCallArchitectures = "native";

                RestrictAddressFamilies = "none";
                CapabilityBoundingSet = [ "" ];
                SystemCallFilter = [
                  "@system-service"
                  "~@privileged"
                  "~@resources"
                ];
                UMask = "0077";
              };
            };
          };
      };
    };
}
