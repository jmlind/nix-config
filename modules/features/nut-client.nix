{
  flake.modules.nixos.nut = {
    power.ups = {
      enable = true;
      mode = "netclient";

      upsmon.monitor."ups" = {
        system = "ups@pi301.local";
        powerValue = 1;
        user = "observer";
        passwordFile = "/etc/nixos/ups-passwd";
        type = "slave";
      };
    };
  };
}
