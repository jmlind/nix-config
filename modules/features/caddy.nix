{
  flake.modules.nixos.caddy =
    { pkgs, config, lib, ... }:
    {
      options.homelab.baseDomain = lib.mkOption {
        type = lib.types.str;
        default = "lind.estate";
        description = "Base domain for anything this host fronts through Caddy, e.g. status.<baseDomain>.";
      };

      config = {
        services.caddy = {
          enable = true;
          package = pkgs.caddy.withPlugins {
            plugins = [ "github.com/caddy-dns/porkbun@v0.3.1" ];
            hash = "sha256-CjL8dMdnsiawaPiQGRvL3he4Ydd3nIbQs6tBWMwUbaw=";
          };
          globalConfig = ''
            acme_dns porkbun {
              api_key {env.PORKBUN_API_KEY}
              api_secret_key {env.PORKBUN_API_SECRET_KEY}
            }
          '';
        };

        networking.firewall.allowedTCPPorts = [ 443 ];
      };
    };
}
