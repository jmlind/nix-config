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

    # NOTE: verify this path against the immich version actually deployed —
    # just checking for a 200 here rather than asserting a response body.
    # Requires `healthEndpoints` (declares this option) somewhere in the
    # host's import closure — see modules/features/health-endpoints.nix.
    healthChecks = [
      {
        name = "immich";
        url = "http://localhost:2283/api/server/ping";
      }
    ];
  };
}
