{ self, lib, ... }:
let
  hostIPs = self.homelabHosts;
  # Every plain-hostname Caddy vhost on any host resolves to that host.
  # Keys like ":80" or "http://x" are not names and are skipped.
  allRecords = lib.concatMap
    (node:
      map (fqdn: { inherit fqdn; host = node.config.networking.hostName; })
        (lib.filter (name: builtins.match "[a-z0-9.-]+[.][a-z]+" name != null)
          (lib.attrNames node.config.services.caddy.virtualHosts)))
    (lib.attrValues self.nixosConfigurations);
in {
  flake.modules.nixos.dns-server = {
    networking.firewall.allowedUDPPorts = [ 53 ];
    networking.firewall.allowedTCPPorts = [ 53 ];
    services.dnsmasq = {
      enable = true;
      settings = {
        # host-record matches only the exact name; address=/x/ would also
        # capture subdomains like _acme-challenge.x and answer them empty.
        host-record = map (r: "${r.fqdn},${hostIPs.${r.host}}") allRecords;
        server = [ "1.1.1.1" "9.9.9.9" ]; # forward everything else upstream
      };
    };

    healthChecks = [
      {
        name = "dns-server";
        url = "tcp://localhost:53";
        conditions = [ "[CONNECTED] == true" ];
      }
    ];
  };
}
