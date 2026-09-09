{
  flake.modules.nixos.caddy = { pkgs, config, ... }: {
    services.caddy = {
      package = pkgs.caddy.withPlugins {
        plugins = [ "github.com/caddy-dns/porkbun@..." ];
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
}
