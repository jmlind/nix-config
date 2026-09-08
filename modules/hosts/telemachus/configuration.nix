{ self, inputs, ... }: {

  flake.nixosModules.telemachusConfiguration = { pkgs, lib, ... }: {
    imports = with self.modules.nixos; [
      telemachusHardware
      jellyfin
      immich
      nut-client
      diskoGptLvm
      nix-settings
    ];

    diskoConfig.primaryDisk = "/dev/nvme0n1";

    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];

    boot.loader.grub = {
      # no need to set devices, disko will add all devices that have a EF02 partition to the list already
      # devices = [ ];
      efiSupport = true;
      efiInstallAsRemovable = true;
    };

    services.openssh.enable = true;

    environment.systemPackages = map lib.lowPrio [
      pkgs.curl
      pkgs.gitMinimal
    ];

    users.users.root.openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCTrHuvuR8Typ/NdoCxm+mFD4ve+SD5m6HcN3vhN3Fdrzpd2RljsyuJlIz46Opmudqf9BmvbMSQa0FlOpzLLWo2IyosYqMCfduYnWO34Icw29D3DRZrO9mrO8bVPBOlXKUjJ2cxrLewIhFqZVc5sI0of+rv3qNQl5m+novil3QGsjkNTjjqtA5y88XpnKmDK45I7GiaTf52Yzr1d81s5t2ltZcWg4mI/zJqNtv9tNElQ/B+yzSmD/OXL7eBv+8rT51tumLMn/sfVKZ14zSVZM6PpRgpTtJpzUOI6zMHkOJ8wSyd4DkEEth2ENHJ9mnT1Nkjfey0xrUvyjCINkReGJBmARHRCePw2momWKEKNS4bX8oKvTynJir7jmHRlQbjnOt5aa0UN+T4nPPl5bovMCvnUMpHctH7azHlDsk9y1TWWqZGlXrbVi93Lpxa15LHHlkGc6TR12VJ/CS8zsW7CyXg6cQt9Z/C1lwJ/6kySCcYhqeTNpIxgmIF8qbiqB40z3c= laptop@fedora"
    ];

    system.stateVersion = "24.05";
  };

}
