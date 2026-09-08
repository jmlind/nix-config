{ inputs, ... }: {
  flake.modules.nixos.porkbun-secrets = { config, ... }: {
    imports = [ inputs.self.modules.nixos.sops ];

    sops.secrets."porkbun/api_key".sopsFile = ../../secrets/porkbun.yaml;
    sops.secrets."porkbun/api_secret_key".sopsFile = ../../secrets/porkbun.yaml;

    # Rendered for services.caddy.environmentFile (see ./caddy.nix), which
    # reads these as {env.PORKBUN_API_KEY} / {env.PORKBUN_API_SECRET_KEY}.
    sops.templates."porkbun.env" = {
      content = ''
        PORKBUN_API_KEY=${config.sops.placeholder."porkbun/api_key"}
        PORKBUN_API_SECRET_KEY=${config.sops.placeholder."porkbun/api_secret_key"}
      '';
      restartUnits = [ "caddy.service" ];
    };
  };
}
