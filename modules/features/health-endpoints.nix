{
  flake.modules.nixos.healthEndpoints =
    { lib, ... }:
    {
      options.healthChecks = lib.mkOption {
        type = lib.types.listOf (
          lib.types.submodule {
            options = {
              name = lib.mkOption {
                type = lib.types.str;
                description = ''
                  Label shown on the status page. A name that is also in
                  `homelabServices` links to https://<name>.<homelabDomain>.
                '';
              };
              icon = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "File name in modules/features/status-page/icons, e.g. \"jellyfin.png\".";
              };
              description = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Second line on the service card, e.g. \"Media server\".";
              };
              url = lib.mkOption {
                type = lib.types.str;
                description = ''
                  "http://localhost:8096/health" for an HTTP check (any
                  2xx/3xx is up), or "tcp://localhost:53" to only ping the
                  host (homepage has no TCP port check).
                '';
              };
            };
          }
        );
        default = [ ];
        description = "Endpoints this host's imported features expose for the status page to monitor.";
      };
    };
}
