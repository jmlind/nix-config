# Single source of truth for each host's LAN address. Shared by
# dns-server.nix (local DNS records) and status-page.nix (rewriting
# "localhost" health-check URLs to a reachable address when aggregating
# checks from every host into one dashboard).
{
  flake.homelabHosts = {
    homelab = "192.168.1.168";
    telemachus = "192.168.1.169";
  };
}
