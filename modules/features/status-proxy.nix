# Reverse-proxies the one unified gatus status page (status-page.nix)
# behind Caddy at status.<baseDomain>, kept LAN-only even though it gets a
# real cert: the porkbun DNS-01 challenge in caddy.nix proves domain
# ownership without needing 80/443 reachable from the internet, so the
# hostname resolves with valid TLS while access is still gated inside
# Caddy (`remote_ip` matcher), not just left to the firewall.
#
# Import this only on the host running statusPage (currently: telemachus),
# alongside `caddy`.
{
  flake.modules.nixos.statusProxy =
    { config, lib, ... }:
    {
      options.homelab.baseDomain = lib.mkOption {
        type = lib.types.str;
        default = "lind.estate";
        description = "Base domain the unified status page is served under, as status.<baseDomain>.";
      };

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
