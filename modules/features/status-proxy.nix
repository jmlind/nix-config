# Reverse-proxies a host's own gatus status page (modules/features/
# status-page.nix) behind Caddy at status.<hostname>.<baseDomain>, kept
# LAN-only even though it gets a real cert: the porkbun DNS-01 challenge
# in caddy.nix proves domain ownership without needing 80/443 reachable
# from the internet, so the hostname resolves and has valid TLS without
# ever being internet-facing. Access is gated inside Caddy itself, not
# just left to the firewall/router.
#
# A host wanting this needs `caddy`, `statusPage`, and `statusProxy` all
# in its imports, and networking.hostName set (used to build the vhost).
{
  flake.modules.nixos.statusProxy =
    { config, lib, ... }:
    {
      options.homelab.baseDomain = lib.mkOption {
        type = lib.types.str;
        default = "lind.estate";
        description = "Base domain status pages are served under, as status.<hostname>.<baseDomain>.";
      };

      services.caddy.virtualHosts."status.${config.networking.hostName}.${config.homelab.baseDomain}" = {
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
