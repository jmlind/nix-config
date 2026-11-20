{
  # Remote access through Tailscale (free Personal plan). This host joins the
  # tailnet as a subnet router for the LAN, so a phone or laptop anywhere
  # reaches every LAN address (and every lind.estate name) without a port
  # forward. Nothing on this host is opened to the internet: Tailscale
  # punches out through NAT, or falls back to its DERP relays.
  #
  # One-time, after the first deploy:
  #   sudo tailscale up            # log in with the printed URL
  #   then in the admin console (login.tailscale.com):
  #     - Machines > this host > Edit route settings: approve 192.168.1.0/24
  #     - Machines > this host > Disable key expiry
  #     - DNS > Add nameserver > Custom: 192.168.1.190, "Restrict to domain"
  #       lind.estate (split DNS through this host's dnsmasq)
  flake.modules.nixos.tailscale =
    { lib, options, ... }:
    let
      lan = "192.168.1.0/24";
      tailnet = [
        "100.64.0.0/10" # Tailscale CGNAT range, IPv4
        "fd7a:115c:a1e0::/48" # Tailscale ULA range, IPv6
      ];
    in
    {
      config = {
        services.tailscale = {
          enable = true;
          openFirewall = true; # UDP 41641, for direct (non-relayed) paths
          # "server" turns on IP forwarding, which a subnet router needs.
          useRoutingFeatures = "server";
          # Applied with `tailscale set` on every start, so the routes are
          # declared here, not only in the state left by `tailscale up`.
          extraSetFlags = [
            "--advertise-routes=${lan}"
            # This host is the DNS server; keep its own resolver config.
            "--accept-dns=false"
          ];
        };

        # Tailnet peers are authenticated by Tailscale; let them reach the
        # same ports LAN clients can (DNS, HTTPS, SSH).
        networking.firewall.trustedInterfaces = [ "tailscale0" ];
      }
      # Traffic to this host's own services arrives from a 100.x address,
      # not from the LAN; let Caddy's LAN-only vhosts accept it.
      // lib.optionalAttrs (options ? caddyAccess) {
        caddyAccess.allowedRanges = tailnet;
      };
    };
}
