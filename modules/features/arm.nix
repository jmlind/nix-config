{ inputs, ... }: {
  flake.modules.nixos.arm = { pkgs, config, ... }: {
    imports = [
      inputs.self.modules.nixos.nas-media
      inputs.self.modules.nixos.containers
    ];

    # pkgs
    environment.systemPackages = [
      pkgs.lsscsi
      pkgs.libdvdread
    ];

    # Load the 'sg' kernel module to allow the container to see disk drives
    boot.kernelModules = [ "sg" ];

    # Enable udev to allow the container to see disk drives and other devices
    services.udev.enable = true;

    # Open port 8080 for the web UI of the container
    networking.firewall.allowedTCPPorts = [ 8080 ];

    # Create a group 'arm' for the container
    users.groups.arm = {
      gid = 1100;
    };

    # Create a user 'arm' for the container; set the password with `passwd`
    users.users.arm = {
      isNormalUser = true;
      description = "arm";
      group = "arm";
      uid = 1100;
      extraGroups = [
        "arm"
        "cdrom"
        "video"
        "render"
        config.mediaMount.group
      ];
    };

    # set up directories with arm user and group ownership
    systemd.tmpfiles.rules = [
      "d /home/arm/logs 0755 arm arm -"
      "d /home/arm/music 0755 arm arm -"
      "d /home/arm/media 0755 arm arm -"
      "d /home/arm/config 0755 arm arm -"
    ];
    # Configure the ARM container
    virtualisation.oci-containers.containers."arm" = {
      autoStart = true; # Automatically start the container on boot
      image = "automaticrippingmachine/automatic-ripping-machine:2.24.0";
      ports = [ "8080:8080" ];
      # TODO: Use id arm to get the UID and GID for the arm user after creation
      environment = {
        ARM_UID = toString config.users.users.arm.uid;
        ARM_GID = toString config.users.groups.arm.gid;
      };

      # Mount 'host directory' to 'container directory'
      volumes = [
        "${config.mediaMount.mountPoint}:/mnt/arm"
        "/home/arm:/home/arm"
        "/home/arm/music:/home/arm/music"
        "/home/arm/logs:/home/arm/logs"
        "/home/arm/media:/home/arm/media"
        "/home/arm/config:/etc/arm/config"
      ];
      extraOptions = [
        "--device=/dev/sr0:/dev/sr0" # Pass through the CD/DVD drive
        #"--device=/dev/dri:/dev/dri"
        "--privileged" # Run the container in privileged mode
        # The container has no "mediaMount.group" entry of its own, so
        # docker can't resolve that name via --group-add; pass the group's
        # (static) gid instead, which needs no /etc/group lookup.
        "--group-add=${toString config.mediaMount.gid}"
      ];

    };
  };
}
