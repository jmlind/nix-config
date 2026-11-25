{
  # Incus with its web UI, plus one VM sized like an AWS t3.medium.
  # POC: the VM is created once by a oneshot unit; Nix does not manage it
  # after that (resize or delete it from the UI or `incus`).
  flake.modules.nixos.incus =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.incus;
      bridge = "incusbr0";
      incus = lib.getExe' config.virtualisation.incus.package "incus";
    in
    {
      options.incus = {
        uiPort = lib.mkOption {
          type = lib.types.port;
          default = 8443;
          description = "HTTPS port for the Incus API and web UI.";
        };
        lan = lib.mkOption {
          type = lib.types.str;
          default = "192.168.1.0/24";
          description = "Only this subnet may reach the web UI.";
        };
        vm = {
          name = lib.mkOption {
            type = lib.types.str;
            default = "poc";
            description = "Name of the VM launched on first boot.";
          };
          image = lib.mkOption {
            type = lib.types.str;
            default = "images:debian/13";
            description = "Image for the VM.";
          };
        };
      };

      config = {
        virtualisation.incus = {
          enable = true;
          ui.enable = true;
          preseed = {
            config."core.https_address" = ":${toString cfg.uiPort}";
            networks = [
              {
                name = bridge;
                type = "bridge";
                config = {
                  "ipv4.address" = "10.0.100.1/24";
                  "ipv4.nat" = "true";
                  "ipv6.address" = "none";
                };
              }
            ];
            storage_pools = [
              {
                name = "default";
                driver = "dir";
                config.source = "/var/lib/incus/storage-pools/default";
              }
            ];
            profiles = [
              {
                name = "default";
                devices = {
                  eth0 = {
                    name = "eth0";
                    network = bridge;
                    type = "nic";
                  };
                  root = {
                    path = "/";
                    pool = "default";
                    size = "20GiB";
                    type = "disk";
                  };
                };
              }
              {
                # Same shape as an AWS t3.medium.
                name = "medium";
                description = "2 vCPU, 4 GiB memory";
                config = {
                  "limits.cpu" = "2";
                  "limits.memory" = "4GiB";
                };
                devices = { };
              }
            ];
          };
        };

        # Incus only supports the nftables firewall on NixOS.
        networking.nftables.enable = true;
        # Instances get DHCP and DNS from Incus's dnsmasq on the bridge.
        networking.firewall.trustedInterfaces = [ bridge ];
        # Web UI: LAN only, like the Caddy vhosts.
        networking.firewall.extraInputRules = ''
          ip saddr ${cfg.lan} tcp dport ${toString cfg.uiPort} accept
        '';

        # Docker sets the FORWARD policy to DROP, which cuts the bridge off
        # from the internet. Docker's own rules still apply to its networks.
        virtualisation.docker.daemon.settings = lib.mkIf config.virtualisation.docker.enable {
          ip-forward-no-drop = true;
        };

        # A host-wide dnsmasq (dns-server) would hold port 53 on the bridge
        # address, and Incus's own dnsmasq could not start.
        services.dnsmasq.settings = lib.mkIf config.services.dnsmasq.enable {
          bind-dynamic = true;
          except-interface = bridge;
        };

        systemd.services.incus-vm = {
          description = "Launch Incus VM ${cfg.vm.name}";
          wantedBy = [ "multi-user.target" ];
          after = [ "incus-preseed.service" "network-online.target" ];
          requires = [ "incus-preseed.service" ];
          wants = [ "network-online.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            # The image download can fail while the network comes up.
            Restart = "on-failure";
            RestartSec = 30;
          };
          script = ''
            if ! ${incus} info ${cfg.vm.name} >/dev/null 2>&1; then
              ${incus} launch ${cfg.vm.image} ${cfg.vm.name} --vm --profile default --profile medium
            fi
          '';
        };
      };
    };
}
