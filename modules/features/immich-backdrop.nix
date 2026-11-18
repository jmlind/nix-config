{ inputs, ... }:
{
  # Status page background: a random photo from one Immich album. A helper
  # holds the API key so it never reaches the browser.
  flake.modules.nixos.immichBackdrop =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.immichBackdrop;
    in
    {
      imports = [ inputs.self.modules.nixos.sops ];

      options.immichBackdrop = {
        albumId = lib.mkOption {
          type = lib.types.str;
          description = "Immich album to take background photos from (the UUID in the album's URL).";
        };
        immichUrl = lib.mkOption {
          type = lib.types.str;
          default = "http://localhost:${toString config.services.immich.port}";
          description = "Immich server, reached from this host.";
        };
        port = lib.mkOption {
          type = lib.types.port;
          default = inputs.self.homelabServices.backdrop.port;
          description = "Local port; caddy proxies backdrop.<homelabDomain> to it.";
        };
        url = lib.mkOption {
          type = lib.types.str;
          readOnly = true;
          default = "https://backdrop.${inputs.self.homelabDomain}/";
          description = "Public URL of the backdrop, for statusPage.";
        };
      };

      config = {
        # Key needs Immich permissions asset.read and asset.view.
        sops.secrets."immich_api_key" = {
          sopsFile = ./secrets.yaml;
          restartUnits = [ "immich-backdrop.service" ];
        };

        systemd.services.immich-backdrop = {
          description = "Random Immich album photo for the status page";
          wantedBy = [ "multi-user.target" ];
          after = [ "network.target" ];
          environment = {
            IMMICH_URL = cfg.immichUrl;
            ALBUM_ID = cfg.albumId;
            PORT = toString cfg.port;
            ALLOW_ORIGIN = "https://status.${inputs.self.homelabDomain}";
          };
          serviceConfig = {
            ExecStart = "${lib.getExe pkgs.python3} ${./immich-backdrop/backdrop.py}";
            LoadCredential = "immich-api-key:${config.sops.secrets."immich_api_key".path}";
            Restart = "on-failure";
            DynamicUser = true;
            CapabilityBoundingSet = "";
            NoNewPrivileges = true;
            PrivateDevices = true;
            PrivateTmp = true;
            ProtectHome = true;
            ProtectSystem = "strict";
            RestrictAddressFamilies = [
              "AF_INET"
              "AF_INET6"
            ];
          };
        };
      };
    };
}
