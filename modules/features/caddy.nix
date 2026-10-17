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
      config = {
        services.caddy = {
          enable = true;
          package = pkgs.caddy.withPlugins {
            plugins = [ "github.com/caddy-dns/porkbun@v0.3.1" ];
            hash = "sha256-CjL8dMdnsiawaPiQGRvL3he4Ydd3nIbQs6tBWMwUbaw=";
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

          # The service table lives in dns-server.nix; every vhost is LAN-only.
          virtualHosts = lib.mapAttrs' (
            name: svc:
            let
              upstream =
                if svc.host == config.networking.hostName then "localhost" else inputs.self.homelabHosts.${svc.host};
            in
            lib.nameValuePair "${name}.${inputs.self.homelabDomain}" {
              extraConfig = ''
                @lan remote_ip 192.168.1.0/24 127.0.0.1
                handle @lan {
                  reverse_proxy ${upstream}:${toString svc.port}
                }
                respond 403
              '';
            }
          ) inputs.self.homelabServices;
        };

        networking.firewall.allowedTCPPorts = [ 80 443 ]; # 80 only redirects to https
      };
    };
}
