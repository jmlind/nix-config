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
  };
}
