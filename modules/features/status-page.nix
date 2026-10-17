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
    };
}
