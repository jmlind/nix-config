{ self, lib, ... }:
let
  hostIPs = self.homelabHosts;
  allRecords = lib.foldl'
    (acc: node: acc // (node.config.homelab.dns.records or { }))
    { }
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
        host-record = lib.mapAttrsToList
          (fqdn: host: "${fqdn},${hostIPs.${host}}")
          allRecords;
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
