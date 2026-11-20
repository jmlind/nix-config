{ inputs, ... }: {
  flake.modules.nixos.caddy =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      imports = [ inputs.self.modules.nixos.porkbun-secrets ];

      options.caddyAccess.allowedRanges = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = ''
          Client address ranges every vhost accepts; others get 403. Other
          features append to it (e.g. tailscale adds its tailnet range).
        '';
      };

      config = {
        caddyAccess.allowedRanges = [ "192.168.1.0/24" "127.0.0.1" ];

        services.caddy = {
          enable = true;
          package = pkgs.caddy.withPlugins {
            plugins = [ "github.com/caddy-dns/porkbun@v0.3.1" ];
            hash = "sha256-8DrezGjdIUq9tBvbK7UuVDeQPuzUdBsmIkI79YDCTOQ=";
          };
          environmentFile = config.sops.templates."porkbun.env".path;
          # Porkbun's nameservers can take minutes to serve a new TXT record,
          # longer than Caddy's default 2m propagation timeout. Public
          # resolvers keep the check off this host's own dnsmasq.
          globalConfig = ''
            cert_issuer acme {
              dns porkbun {
                api_key {env.PORKBUN_API_KEY}
                api_secret_key {env.PORKBUN_API_SECRET_KEY}
              }
              resolvers 1.1.1.1 9.9.9.9
              propagation_delay 30s
              propagation_timeout 10m
            }
          '';

          # The service table lives in dns-server.nix; every vhost is limited to
          # caddyAccess.allowedRanges.
          virtualHosts = lib.mapAttrs' (
            name: svc:
            let
              upstream =
                if svc.host == config.networking.hostName then "localhost" else inputs.self.homelabHosts.${svc.host};
            in
            lib.nameValuePair "${name}.${inputs.self.homelabDomain}" {
              extraConfig = ''
                @allowed remote_ip ${lib.concatStringsSep " " config.caddyAccess.allowedRanges}
                handle @allowed {
                  reverse_proxy ${upstream}:${toString svc.port}
                }
                respond 403
              '';
            }
          ) inputs.self.homelabServices;
        };

        networking.firewall.allowedTCPPorts = [ 80 443 ]; # 80 only redirects to https

        # Checked through a vhost, so a bad cert shows as down.
        healthChecks = [
          {
            name = "caddy";
            url = "https://status.${inputs.self.homelabDomain}";
            icon = "caddy.png";
            description = "Reverse proxy";
          }
        ];
      };
    };
}
