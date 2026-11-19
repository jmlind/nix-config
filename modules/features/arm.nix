{ inputs, ... }: {
  flake.modules.nixos.arm = { pkgs, config, ... }: {
    imports = [
      inputs.self.modules.nixos.nas-media
      inputs.self.modules.nixos.containers
      inputs.self.modules.nixos.healthEndpoints
    ];

    environment.systemPackages = [
      pkgs.lsscsi
      pkgs.libdvdread
    ];

    # sg + udev let the container see the optical drive.
    boot.kernelModules = [ "sg" ];
    services.udev.enable = true;

    networking.firewall.allowedTCPPorts = [ 8080 ];

    healthChecks = [
      {
        name = "arm";
        url = "http://localhost:8080";
        icon = "disc-player.svg";
        description = "Disc ripping";
      }
    ];

    # The NAS share is mounted under arm's own group, dedicated to this container.
    mediaMount.group = "arm";
    mediaMount.gid = 1100;

    # Fixed uid/gid: ARM_UID/ARM_GID and the mount must agree across rebuilds.
    # Set the password with `passwd`.
    users.users.arm = {
      isNormalUser = true;
      description = "arm";
      group = config.mediaMount.group;
      uid = 1100;
      extraGroups = [
        "cdrom"
        "video"
        "render"
      ];
    };

    systemd.tmpfiles.rules = [
      "d /home/arm/logs 0755 arm arm -"
      "d /home/arm/music 0755 arm arm -"
      "d /home/arm/media 0755 arm arm -"
      "d /home/arm/config 0755 arm arm -"
    ];

    virtualisation.oci-containers.containers."arm" = {
      autoStart = true;
      image = "automaticrippingmachine/automatic-ripping-machine:2.24.0";
      ports = [ "8080:8080" ];
      environment = {
        ARM_UID = toString config.users.users.arm.uid;
        ARM_GID = toString config.mediaMount.gid;
      };

      volumes = [
        "${config.mediaMount.mountPoint}:/mnt/arm"
        "/home/arm:/home/arm"
        "/home/arm/music:/home/arm/music"
        "/home/arm/logs:/home/arm/logs"
        "/home/arm/media:/home/arm/media"
        "/home/arm/config:/etc/arm/config"
      ];
      extraOptions = [
        "--device=/dev/sr0:/dev/sr0"
        #"--device=/dev/dri:/dev/dri"
        "--privileged"
        # Numeric gid: the group name doesn't exist inside the container.
        "--group-add=${toString config.mediaMount.gid}"
      ];

    };
  };
}
