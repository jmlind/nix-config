{ self, ... }: {

  flake.nixosModules.homelabConfiguration = { config, ... }: {
    imports = with self.modules.nixos; [
      homelabHardware
      arm
      nix-settings
    ];

    networking.hostName = "homelab";

    # Resolve names (lind.estate, LAN hosts) through telemachus's dnsmasq.
    networking.nameservers = [ self.homelabHosts.telemachus ];

    boot.loader.grub.enable = true;
    boot.loader.grub.device = "/dev/sda";

    time.timeZone = "America/Chicago";

    # Deploy with: nixos-rebuild switch --flake .#homelab --target-host root@homelab
    # The homelab user + passwordless sudo is the fallback login.
    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "prohibit-password";
      };
    };

    users.users.root.openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCTrHuvuR8Typ/NdoCxm+mFD4ve+SD5m6HcN3vhN3Fdrzpd2RljsyuJlIz46Opmudqf9BmvbMSQa0FlOpzLLWo2IyosYqMCfduYnWO34Icw29D3DRZrO9mrO8bVPBOlXKUjJ2cxrLewIhFqZVc5sI0of+rv3qNQl5m+novil3QGsjkNTjjqtA5y88XpnKmDK45I7GiaTf52Yzr1d81s5t2ltZcWg4mI/zJqNtv9tNElQ/B+yzSmD/OXL7eBv+8rT51tumLMn/sfVKZ14zSVZM6PpRgpTtJpzUOI6zMHkOJ8wSyd4DkEEth2ENHJ9mnT1Nkjfey0xrUvyjCINkReGJBmARHRCePw2momWKEKNS4bX8oKvTynJir7jmHRlQbjnOt5aa0UN+T4nPPl5bovMCvnUMpHctH7azHlDsk9y1TWWqZGlXrbVi93Lpxa15LHHlkGc6TR12VJ/CS8zsW7CyXg6cQt9Z/C1lwJ/6kySCcYhqeTNpIxgmIF8qbiqB40z3c= laptop@fedora"
    ];

    users.users.homelab = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = config.users.users.root.openssh.authorizedKeys.keys;
    };

    security.sudo.wheelNeedsPassword = false;

    system.stateVersion = "24.11"; # first install; never change
  };

}
