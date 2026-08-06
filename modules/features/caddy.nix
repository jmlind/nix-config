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
  };
}
