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
                description = "Label shown on the status page.";
              };
              url = lib.mkOption {
                type = lib.types.str;
                description = ''
                  gatus endpoint URL, e.g. "http://localhost:8096/health"
                  for an HTTP check or "tcp://localhost:53" for a TCP check.
                '';
              };
              interval = lib.mkOption {
                type = lib.types.str;
                default = "60s";
              };
              conditions = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ "[STATUS] == 200" ];
                description = "gatus condition expressions, e.g. [STATUS] == 200 or [CONNECTED] == true.";
              };
            };
          }
        );
        default = [ ];
        description = "Endpoints this host's imported features expose for the status page to monitor.";
      };
    };
}
