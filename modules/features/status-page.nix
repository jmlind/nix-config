{ self, lib, ... }:
{
  flake.modules.nixos.statusPage =
    {
      config,
      options,
      pkgs,
      ...
    }:
    let
      domain = self.homelabDomain;
      # Disk widget for the NAS share when this host mounts it (nas-media,
      # e.g. via jellyfin). Not imported here: nas-media has no module key,
      # so a second import would declare its options twice.
      mediaMount = lib.optionalString (options ? mediaMount) config.mediaMount.mountPoint;

      # One homepage group per host, holding that host's healthChecks.
      # `localhost` becomes the host's LAN address, since this one page
      # checks every host's services.
      groups = lib.concatMap (
        node:
        let
          hostName = node.config.networking.hostName;
          checks = node.config.healthChecks or [ ];
          toService =
            hc:
            let
              url = lib.replaceStrings [ "localhost" ] [ self.homelabHosts.${hostName} ] hc.url;
            in
            {
              ${hc.name} =
                (
                  if lib.hasPrefix "tcp://" url then
                    { ping = lib.head (lib.splitString ":" (lib.removePrefix "tcp://" url)); }
                  else
                    { siteMonitor = url; }
                )
                // lib.optionalAttrs (self.homelabServices ? ${hc.name}) {
                  href = "https://${hc.name}.${domain}";
                };
            };
        in
        lib.optional (checks != [ ]) { ${hostName} = map toService checks; }
      ) (lib.attrValues self.nixosConfigurations);
    in
    {
      imports = [
        self.modules.nixos.healthEndpoints
        self.modules.nixos.caddy
      ];

      services.homepage-dashboard = {
        enable = true;
        listenPort = self.homelabServices.status.port;
        # caddy forwards the original Host header
        allowedHosts = "status.${domain},localhost:${toString self.homelabServices.status.port}";
        settings = {
          title = domain;
          theme = "dark";
          color = "slate";
          headerStyle = "clean";
          layout = lib.genAttrs (lib.concatMap lib.attrNames groups) (_: {
            style = "row";
            columns = 3;
          });
        };
        widgets = lib.optional (mediaMount != "") {
          resources = {
            label = "NAS media";
            disk = mediaMount;
            expanded = true;
          };
        };
        services = groups;
      };

      systemd.services.homepage-dashboard = {
        # `ping` checks (tcp:// healthChecks); unprivileged ICMP sockets,
        # allowed by NixOS's default net.ipv4.ping_group_range.
        path = [ pkgs.iputils ];
        # The disk widget only sees the share once the automount has fired.
        # Wants, not Requires: a down NAS must not take the page down.
        unitConfig = lib.optionalAttrs (mediaMount != "") { WantsMountsFor = mediaMount; };
      };
    };
}
