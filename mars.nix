{ pkgs, ... }: {
  # Pin the gid: it's referenced from arm.nix (ARM_GID) so the arm
  # container's process gid always matches the group the CIFS mount below
  # forces onto every file/dir. Without a fixed gid here, NixOS would leave
  # it to be assigned at activation time and it couldn't be read from config.
  # 986 is the group's current gid on the host (confirmed via live testing).
  users.groups.nas-media.gid = 986;

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
