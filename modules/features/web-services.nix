{
  flake.modules.nixos.webServices =
    { lib, ... }:
    {
      # caddy, jellyfin, immich, arm, ... all self-import this module. A fixed
      # key makes the module system load it once per host; without it the
      # option is declared twice and evaluation fails with "already declared".
      key = "nix-config#webServices";

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
