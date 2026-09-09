# One unified status page, not one per host: aggregates the `healthChecks`
# every host registered (see health-endpoints.nix) across *all* of
# self.nixosConfigurations, tags each with `group = <hostname>` so gatus's
# UI sections the dashboard by host, and rewrites "localhost" in each URL
# to that host's real LAN address (modules/network.nix) so a single gatus
# instance can reach every host's services, not just its own.
#
# Import this on exactly one host — the one that will actually run the
# dashboard (currently: telemachus). Every other host just needs
# `healthEndpoints` (not this) if it wants to register its own checks —
# see health-endpoints.nix and CLAUDE.md for why those are separate.
{ self, lib, ... }:
{
  flake.modules.nixos.statusPage =
    { ... }:
    let
      allChecks = lib.concatMap
        (
          node:
          let
            hostName = node.config.networking.hostName;
          in
          map (hc: hc // {
            group = hostName;
            url = lib.replaceStrings [ "localhost" ] [ self.homelabHosts.${hostName} ] hc.url;
          }) (node.config.healthChecks or [ ])
        )
        (lib.attrValues self.nixosConfigurations);
    in
    {
      services.gatus = {
        enable = true;
        settings.endpoints = map (hc: {
          inherit (hc) name url interval conditions group;
        }) allChecks;
      };

      # gatus has no openFirewall option; put it behind caddy (or another
      # reverse proxy) for real exposure — see status-proxy.nix.
      networking.firewall.allowedTCPPorts = [ 8080 ];
    };
}
