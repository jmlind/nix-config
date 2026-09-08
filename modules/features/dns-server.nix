{ self, lib, ... }:
let
  hostIPs = {
    homelab    = "192.168.1.168";
    telemachus = "192.168.1.169";
  };
  allRecords = lib.foldl'
    (acc: node: acc // node.config.homelab.dns.records)
    { }
    (lib.attrValues self.nixosConfigurations);
in {
  flake.modules.nixos.dns-server = {
    networking.firewall.allowedUDPPorts = [ 53 ];
    networking.firewall.allowedTCPPorts = [ 53 ];
    services.dnsmasq = {
      enable = true;
      settings = {
        address = lib.mapAttrsToList
          (fqdn: host: "/${fqdn}/${hostIPs.${host}}")
          allRecords;
        server = [ "1.1.1.1" "9.9.9.9" ]; # forward everything else upstream
      };
    };

    # TCP check, not HTTP: dnsmasq doesn't speak HTTP, but a successful TCP
    # connect on 53 is a reasonable "is it up" signal. Requires `statusPage`
    # (declares this option) somewhere in the host's import closure — see
    # modules/features/health-endpoints.nix.
    healthChecks = [
      {
        name = "dns-server";
        url = "tcp://localhost:53";
        conditions = [ "[CONNECTED] == true" ];
      }
    ];
  };
}
