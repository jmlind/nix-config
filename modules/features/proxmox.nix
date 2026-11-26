{ inputs, ... }:
{
  # Proxmox VE on NixOS through proxmox-nixos (experimental upstream; POC).
  # Web UI: https://proxmox.lind.estate through Caddy, or
  # https://<host>:8006 directly (self-signed cert). Log in as root, realm
  # "Linux PAM": set a root password first (`passwd`), the host has none.
  flake.modules.nixos.proxmox =
    { config, ... }:
    {
      imports = [ inputs.proxmox-nixos.nixosModules.proxmox-ve ];

      config = {
        services.proxmox-ve = {
          enable = true;
          ipAddress = inputs.self.homelabHosts.${config.networking.hostName};
          # Default also opens 80/443 and rpcbind; Caddy already owns 80/443.
          openFirewall = false;
        };
        networking.firewall.allowedTCPPorts = [ 8006 ];

        # Packages come from proxmox-nixos' own pinned nixpkgs, so its cache hits.
        nixpkgs.overlays = [ inputs.proxmox-nixos.overlays.x86_64-linux ];
        nix.settings = {
          substituters = [ "https://cache.saumon.network/proxmox-nixos" ];
          trusted-public-keys = [ "proxmox-nixos:D9RYSWpQQC/msZUWphOY2I5RLH5Dd6yQcaHIuug7dWM=" ];
        };

        # Checked through the vhost: pveproxy's own cert is self-signed.
        healthChecks = [
          {
            name = "proxmox";
            url = "https://proxmox.${inputs.self.homelabDomain}";
            icon = "proxmox.png";
            description = "Hypervisor";
          }
        ];
      };
    };
}
