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

      networking.firewall.allowedTCPPorts = [ 8080 ];

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
