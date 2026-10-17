{ self, lib, ... }:
let
  domain = "lind.estate";
  # Every name below resolves to the proxy host, whose caddy forwards it to
  # `host`:`port`. Add a service here by hand; nothing else declares names.
  proxyHost = "telemachus";
  services = {
    status = { host = "telemachus"; port = 8080; };
    jellyfin = { host = "telemachus"; port = 8096; };
    immich = { host = "telemachus"; port = 2283; };
    arm = { host = "homelab"; port = 8080; };
  };
in
{
  flake.homelabDomain = domain;
  flake.homelabServices = services;

  flake.modules.nixos.dns-server = {
    networking.firewall.allowedUDPPorts = [ 53 ];
    networking.firewall.allowedTCPPorts = [ 53 ];
    services.dnsmasq = {
      enable = true;
      settings = {
        # host-record matches only the exact name; address=/x/ would also
        # capture subdomains like _acme-challenge.x and answer them empty.
        host-record = map (name: "${name}.${domain},${self.homelabHosts.${proxyHost}}") (lib.attrNames services);
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
