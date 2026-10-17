{
  flake.modules.nixos.webServices =
    { lib, ... }:
    {
      options.webServices = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              port = lib.mkOption {
                type = lib.types.port;
                description = "Local port the service listens on.";
              };
              lanOnly = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Reject clients outside the LAN.";
              };
            };
          }
        );
        default = { };
        description = ''
          Web services this host's features expose, keyed by subdomain. A
          reverse proxy (e.g. caddy) on the same host decides how to serve them.
        '';
      };
    };
}
