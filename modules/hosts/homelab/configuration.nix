{ self, inputs, ... }: {

  flake.nixosModules.homelabConfiguration = { pkgs, lib, ... }: {
    # import any other modules from here
    imports = [
      self.nixosModules.myMachineHardware
    ];

    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];

    # ...any other config typically in configuration.nix
    boot.loader.grub.enable = true;
    boot.loader.grub.device = "/dev/sda";
    boot.loader.grub.useOSProber = true;

    # Set your time zone.
    time.timeZone = "America/Chicago";

    # Select internationalisation properties.
    i18n.defaultLocale = "en_US.UTF-8";

    i18n.extraLocaleSettings = {
      LC_ADDRESS = "en_US.UTF-8";
      LC_IDENTIFICATION = "en_US.UTF-8";
      LC_MEASUREMENT = "en_US.UTF-8";
      LC_MONETARY = "en_US.UTF-8";
      LC_NAME = "en_US.UTF-8";
      LC_NUMERIC = "en_US.UTF-8";
      LC_PAPER = "en_US.UTF-8";
      LC_TELEPHONE = "en_US.UTF-8";
      LC_TIME = "en_US.UTF-8";
    };
    users.users.homelab = {
      isNormalUser = true;
      extraGroups = [
        "networkmanager"
        "wheel"
      ];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFIC00UW7jJmEnv1f8T9iXGdjmwJbx33cAHGnAByn8ZR jonathanlind@Jonathans-MacBook-Pro.local"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIANroqKe1n3W6W0T+wQzfOExgmg0be+iw1kO22QrfEf8 jonathan@DESKTOP-SMJ6Q81"
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCTrHuvuR8Typ/NdoCxm+mFD4ve+SD5m6HcN3vhN3Fdrzpd2RljsyuJlIz46Opmudqf9BmvbMSQa0FlOpzLLWo2IyosYqMCfduYnWO34Icw29D3DRZrO9mrO8bVPBOlXKUjJ2cxrLewIhFqZVc5sI0of+rv3qNQl5m+novil3QGsjkNTjjqtA5y88XpnKmDK45I7GiaTf52Yzr1d81s5t2ltZcWg4mI/zJqNtv9tNElQ/B+yzSmD/OXL7eBv+8rT51tumLMn/sfVKZ14zSVZM6PpRgpTtJpzUOI6zMHkOJ8wSyd4DkEEth2ENHJ9mnT1Nkjfey0xrUvyjCINkReGJBmARHRCePw2momWKEKNS4bX8oKvTynJir7jmHRlQbjnOt5aa0UN+T4nPPl5bovMCvnUMpHctH7azHlDsk9y1TWWqZGlXrbVi93Lpxa15LHHlkGc6TR12VJ/CS8zsW7CyXg6cQt9Z/C1lwJ/6kySCcYhqeTNpIxgmIF8qbiqB40z3c= laptop@fedora"
      ];
      packages = with pkgs; [ ];
      shell = pkgs.zsh;
    };

    security.sudo.wheelNeedsPassword = false;
    security.sudo.enable = true;

    # Allow unfree packages
    nixpkgs.config.allowUnfree = true;

    # List packages installed in system profile. To search, run:
    # $ nix search wget
    environment.systemPackages = with pkgs; [
      neovim
      gcc # to install lsp packages in nvim
      unzip # to install packages in nvim
      git
      htop
      iotop
      wget
      curl
      zsh # shell
      stow # to unpack dotfiles
      starship # tryhard prompt
      firefox
      libdvdread # dvd libs
      docker
      lsscsi # dvd drive
      cifs-utils # mounting smb share
      sops
      age
      kitty
      pciutils # provides lspci
      ripgrep
    ];

    programs.zsh.enable = true;
    programs.starship.enable = true;

    networking = {
      hostName = "homelab";
      hostId = "ad1f0b4b";
      firewall.allowedTCPPorts = [ ];
    };

    # networking. enables connecting to user@${hostname}.local
    services.avahi = {
      enable = true;
      nssmdns4 = true;
      publish = {
        enable = true;
        addresses = true;
        domain = true;
        hinfo = true;
        userServices = true;
        workstation = true;
      };
    };

    # OpenSSH for remote management
    services.openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
      };
    };

    # Docker for containers
    virtualisation = {
      docker = {
        enable = true;
        autoPrune = {
          enable = true;
          dates = "weekly";
        };
      };
      oci-containers.backend = "docker";
    };
    # This value determines the NixOS release from which the default
    # settings for stateful data, like file locations and database versions
    # on your system were taken. It‘s perfectly fine and recommended to leave
    # this value at the release version of the first install of this system.
    # Before changing this value read the documentation for this option
    # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
    system.stateVersion = "24.11"; # Did you read the comment?
  };

}
