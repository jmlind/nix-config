{
  flake.modules.nixos.nas-media = { pkgs, config, ... }: {
    # add config here
  };
}
{ pkgs, ... }: {
  users.groups.nas-media = { };

  # mount nas for jellyfin
  fileSystems."/mnt/media" = {
    device = "//mars/media";
    fsType = "cifs";
    options = [
      "credentials=/etc/nixos/mars-secrets"
      "nofail"
      "noauto"
      "x-systemd.automount"

      "gid=nas-media" # homelab
      "file_mode=0664"
      "dir_mode=0775"
    ];
  };
}
