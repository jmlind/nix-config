# Turns whatever `healthChecks` this host's imported features registered
# (see modules/features/health-endpoints.nix) into a gatus status page.
# Import this on any host and its dashboard covers exactly the services
# that host also imports — nothing to keep in sync by hand.
{ self, ... }:
{
  flake.modules.nixos.statusPage =
    { config, ... }:
    {
      imports = [ self.modules.nixos.healthEndpoints ];

      services.gatus = {
        enable = true;
        settings.endpoints = map (hc: {
          inherit (hc) name url interval conditions;
        }) config.healthChecks;
      };

      # gatus has no openFirewall option; put it behind caddy (or another
      # reverse proxy) for real exposure — this just gets it reachable.
      networking.firewall.allowedTCPPorts = [ 8080 ];
    };
}
