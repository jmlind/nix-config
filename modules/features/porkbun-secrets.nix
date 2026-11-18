{ inputs, ... }: {
  flake.modules.nixos.porkbun-secrets = { config, ... }: {
    imports = [ inputs.self.modules.nixos.sops ];

    sops.secrets."porkbun_api_key".sopsFile = ./secrets.yaml; 
    sops.secrets."porkbun_secret_key".sopsFile = ./secrets.yaml; 

    sops.templates."porkbun.env" = {
      content = ''
        PORKBUN_API_KEY=${config.sops.placeholder."porkbun_api_key"}
        PORKBUN_API_SECRET_KEY=${config.sops.placeholder."porkbun_secret_key"}
      '';
      restartUnits = [ "caddy.service" ];
    };
  };
}
