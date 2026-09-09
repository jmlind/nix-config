# One import gives a host the whole unified status page: the healthChecks
# option, gatus itself (aggregating checks across *every* host in
# self.nixosConfigurations, grouped by hostname — see modules/network.nix
# for the LAN address each host's "localhost" URLs get rewritten to), and
# its own Caddy vhost at status.<baseDomain> — same "self-import your
# dependencies" shape as jellyfin.nix pulling in nas-media.
#
# Import this on exactly one host — the one that will actually run the
# dashboard (currently: telemachus). A host that only wants to *report*
# checks without hosting the dashboard itself would need `healthEndpoints`
# imported directly instead — not a real case yet, since the only host
# registering checks (telemachus) is also the one running this.
{ self, lib, ... }:
{
  flake.modules.nixos.statusPage =
    { config, ... }:
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
      imports = [
        self.modules.nixos.healthEndpoints
        self.modules.nixos.caddy
      ];

      services.gatus = {
        enable = true;
        settings.endpoints = map (hc: {
          inherit (hc) name url interval conditions group;
        }) allChecks;
      };

      # gatus has no openFirewall option of its own; direct LAN access on
      # 8080 alongside the Caddy vhost below, not instead of it.
      networking.firewall.allowedTCPPorts = [ 8080 ];

      # baseDomain comes from `caddy` (self-imported above), same relationship
      # as jellyfin reading nas-media's mediaMount.* — LAN-gated here too, not
      # just left to the firewall, even though the cert is real (porkbun
      # DNS-01 in caddy.nix proves ownership without needing 80/443 public).
      services.caddy.virtualHosts."status.${config.homelab.baseDomain}" = {
        extraConfig = ''
          @lan remote_ip 192.168.1.0/24 127.0.0.1
          handle @lan {
            reverse_proxy localhost:8080
          }
          respond 403
        '';
      };
    };
}
