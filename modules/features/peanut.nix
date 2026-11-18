{ inputs, ... }:
{
  # PeaNUT dashboard for the UPS. Configured only from Nix (UI settings are
  # not saved), and given no NUT login, so it is read-only.
  flake.modules.nixos.peanut =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.peanut;
    in
    {
      imports = [ inputs.self.modules.nixos.containers ];

      options.peanut = {
        nutHost = lib.mkOption {
          type = lib.types.str;
          default = inputs.self.homelabHosts.pi301;
          description = "NUT server address.";
        };
        upsName = lib.mkOption {
          type = lib.types.str;
          default = "ups";
          description = "UPS name on the NUT server, shown on the status page card.";
        };
        port = lib.mkOption {
          type = lib.types.port;
          default = inputs.self.homelabServices.peanut.port;
          description = "Host port for the PeaNUT web UI.";
        };
      };

      config = {
        virtualisation.oci-containers.containers.peanut = {
          image = "brandawg93/peanut:6.1.2";
          ports = [ "${toString cfg.port}:8080" ];
          environment = {
            AUTH_DISABLED = "true";
            DISABLE_CONFIG_FILE = "true";
            NUT_SERVERS = builtins.toJSON [
              {
                HOST = cfg.nutHost;
                PORT = 3493;
              }
            ];
          };
        };

        healthChecks = [
          {
            name = "peanut";
            url = "http://localhost:${toString cfg.port}";
            icon = "peanut.png";
            description = "UPS";
            widget = {
              type = "peanut";
              url = "http://localhost:${toString cfg.port}";
              key = cfg.upsName;
            };
          }
        ];
      };
    };
}
