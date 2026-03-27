{
  lib,
  config,
  ...
}:
let
  cfg = config.services.goclaw;
in
{
  /*
     TODO:
    * services.goclaw.env-file for secrets (systemd EnvironmentFile)
    * Only setup postgres locally if no DSN is configured (add option)
    * nginx vhost configurable
    * /ws proxy
    * /assets proxy
    * nginx optional
    * caddy?
    * superuser access for goclaw is a horrowshow. (not solvable without upstream)
  */
  options.services.goclaw = {
    enable = lib.mkEnableOption "GoClaw AI agent gateway";

    package = lib.mkOption {
      type = lib.types.package;
      defaultText = lib.literalMD "`packages.default` from the goclaw flake";
      description = "GoClaw package to use";
    };

    gatewayPort = lib.mkOption {
      type = lib.types.port;
      default = 18790;
      description = "Port for the gateway WebSocket server";
    };

    env = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Additional GoClaw environment variables";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.goclaw = {
      isSystemUser = true;
      group = "goclaw";
      description = "GoClaw AI agent gateway";
    };

    users.groups.goclaw = { };

    services.postgresql = {
      enable = true;
      ensureDatabases = [ "goclaw" ];
      ensureUsers = [
        {
          name = "goclaw";
          ensureDBOwnership = true;
          ensureClauses = {
            superuser = true;
          }; # I hate it, but migrations want to add the vector extension
        }
      ];
      extensions = ps: [ ps.pgvector ];
    };
    systemd.services.goclaw = {
      description = "GoClaw AI agent gateway";
      wantedBy = [ "multi-user.target" ];
      after = [
        "postgresql.service"
        "postgresql-setup.service"
      ];
      serviceConfig = {
        Type = "simple";
        User = "goclaw";
        Group = "goclaw";
        StateDirectory = "goclaw";
        StateDirectoryMode = "0750";
        CacheDirectory = "goclaw";
        PrivateTmp = true;
        PostRestart = "on-failure";
        RestartSec = "5s";
        ExecStartPre = [
          "${cfg.package}/bin/goclaw upgrade"
        ];
        ExecStart = "${cfg.package}/bin/goclaw";
      };
      environment = {
        GOCLAW_CONFIG = "/var/lib/goclaw/config.json";
        GOCLAW_PORT = toString cfg.gatewayPort;
        GOCLAW_POSTGRES_DSN = "postgresql:///goclaw?host=/var/run/postgresql";
      }
      // cfg.env;
    };

    services.nginx = {
      enable = true;
      virtualHosts = {
        "localhost" = {
          root = "${cfg.package}/share/goclaw-web";
          locations."/".index = "index.html";
          locations."/".tryFiles = "$uri $uri/ /index.html";

          locations."/ws" = {
            proxyPass = "http://localhost:${toString cfg.gatewayPort}";
            proxyWebsockets = true;
          };

          locations."/v1" = {
            proxyPass = "http://localhost:${toString cfg.gatewayPort}";
          };

          locations."/health" = {
            proxyPass = "http://localhost:${toString cfg.gatewayPort}";
          };
        };
      };
    };

    networking.firewall.allowedTCPPorts = [
      80
      443
    ];
  };
}
