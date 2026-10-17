{ inputs, ... }: {
  flake.modules.nixos.caddy =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      options.homelab.baseDomain = lib.mkOption {
        type = lib.types.str;
        default = "lind.estate";
        description = "Base domain for anything this host fronts through Caddy, e.g. status.<baseDomain>.";
      };

      options.homelab.dns.records = lib.mkOption {
        type = lib.types.attrsOf (lib.types.enum (lib.attrNames inputs.self.homelabHosts));
        default = { };
        description = "FQDN -> homelabHosts name, served by whichever host imports dns-server.";
      };

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
        };

        networking.firewall.allowedTCPPorts = [ 80 443 ]; # 80 only redirects to https
      };
    };
}
