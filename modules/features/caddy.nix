{
  flake.modules.nixos.caddy =
    { pkgs, config, lib, ... }:
    {
      options.homelab.baseDomain = lib.mkOption {
        type = lib.types.str;
        default = "lind.estate";
        description = "Base domain for anything this host fronts through Caddy, e.g. status.<baseDomain>.";
      };

      # Once a module declares `options.*` explicitly, sibling config has to
      # be nested under `config` too — see nas-media.nix/disko-gpt-lvm.nix.
      config = {
        services.caddy = {
          enable = true;
          package = pkgs.caddy.withPlugins {
            plugins = [ "github.com/caddy-dns/porkbun@v0.3.1" ];
            hash = ""; # nix build will report the correct hash
          };
          globalConfig = ''
            acme_dns porkbun {
              api_key {env.PORKBUN_API_KEY}
              api_secret_key {env.PORKBUN_API_SECRET_KEY}
            }
          '';
        };

        # DNS-01 (porkbun above) doesn't need 80 open to issue certs, but 443
        # does need to be open for anything actually proxied through this host.
        networking.firewall.allowedTCPPorts = [ 443 ];
      };
    };
}
