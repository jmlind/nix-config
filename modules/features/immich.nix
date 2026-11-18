{
  flake.modules.nixos.immich = {
    services.immich = {
      enable = true;
      port = 2283;
      host = "0.0.0.0";
      openFirewall = true;
      database = {
        enable = true;
        name = "immich";
        user = "immich";
        createDB = true;
      };
    };

    healthChecks = [
      {
        name = "immich";
        url = "http://localhost:2283/api/server/ping";
      }
    ];
  };
}
