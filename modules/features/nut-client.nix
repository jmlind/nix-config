{ inputs, ... }: {
  flake.modules.nixos.nut-client = { config, ... }: {
    imports = [ inputs.self.modules.nixos.sops ];

    sops.secrets."nut_observer_password" = {
      sopsFile = ./secrets.yaml;
      restartUnits = [ "upsmon.service" ];
    };

    power.ups = {
      enable = true;
      mode = "netclient";

      upsmon.monitor."ups" = {
        system = "ups@pi301.local";
        powerValue = 1;
        user = "observer";
        passwordFile = config.sops.secrets."nut_observer_password".path;
        type = "slave";
      };
    };
  };
}
