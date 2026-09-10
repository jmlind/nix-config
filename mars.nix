{ pkgs, ... }: {
  # Pin the gid: it's referenced from arm.nix (ARM_GID) so the arm
  # container's process gid always matches the group the CIFS mount below
  # forces onto every file/dir. Without a fixed gid here, NixOS would leave
  # it to be assigned at activation time and it couldn't be read from config.
  # NOTE: if nas-media already has a different gid on the host, either update
  # this value to match or run `sudo groupmod -g 2000 nas-media` (and
  # restart anything using the group) after switching.
  users.groups.nas-media.gid = 2000;

  # mount nas for jellyfin
  fileSystems."/mnt/media" = {
    device = "//mars/media";
    fsType = "cifs";
    options = [
      "credentials=/etc/nixos/mars-secrets"
      "nofail"
      "noauto"
      "x-systemd.automount"

      "uid=1000" # homelab
      "gid=nas-media" # homelab
      "file_mode=0664"
      "dir_mode=0775"
    ];
  };
}
