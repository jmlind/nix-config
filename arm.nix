{ config, pkgs, lib, ... }: {
  # set up directories with arm user and group ownership
  systemd.tmpfiles.rules = [
    "d /home/arm/logs 0755 arm arm -"
    "d /home/arm/music 0755 arm arm -"
    "d /home/arm/media 0755 arm arm -"
    "d /home/arm/config 0755 arm arm -"
  ];

  # Load the 'sg' kernel module to allow the container to see disk drives
  boot.kernelModules = [ "sg" ];

  # Enable udev to allow the container to see disk drives and other devices
  services.udev.enable = true;

  # Open port 8080 for the web UI of the container
  networking.firewall.allowedTCPPorts = [ 8080 ];

  # Create a user 'arm' for the container; set the password with `passwd`
  users.users.arm = {
    isNormalUser = true;
    description = "arm";
    uid = 1001;
    group = "arm";
    extraGroups = [ "arm" "cdrom" "video" "render" "docker" "nas-media" ];
  };

  # Create a group 'arm' for the container
  users.groups.arm = { };

  # Configure the ARM container
  virtualisation.oci-containers.containers."arm" = {
    autoStart = true; # Automatically start the container on boot
    image = "automaticrippingmachine/automatic-ripping-machine:2.24.0";
    ports = [ "8080:8080" ];
    environment = {
      ARM_UID = toString config.users.users.arm.uid; # UID of the 'arm' user on the host system
      # GID of the 'nas-media' group, not the 'arm' group: the CIFS mount at
      # /mnt/media forces gid=nas-media (dir_mode=0775) on every file, so the
      # container process must share that gid to get write access to the share.
      ARM_GID = toString config.users.groups.nas-media.gid;
    };
    # Mount 'host directory' to 'container directory'
    volumes = [
      "/mnt/media:/mnt/arm"
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
    ];
  };
}
