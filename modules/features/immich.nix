{ self, ... }:
{
  flake.modules.nixos.immich = { config, ... }: {
    imports = [ self.modules.nixos.caddy ];

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

    services.caddy.virtualHosts."immich.${config.caddy.baseDomain}".extraConfig =
      "import lan_only localhost:${toString config.services.immich.port}";

    healthChecks = [
      {
        name = "immich";
        url = "http://localhost:2283/api/server/ping";
      }
    ];
  };
}
