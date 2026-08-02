{
  flake.modules.nixos.nas-media = { pkgs, config, ... }: {
    users.groups.nas-media = { };

    # mount nas for nas-media group
    fileSystems."/mnt/media" = {
      device = "//mars/media";
      fsType = "cifs";
      options = [
        "credentials=/etc/nixos/mars-secrets"
        "nofail"
        "noauto"
        "x-systemd.automount"

        "gid=nas-media"
        "file_mode=0664"
        "dir_mode=0775"
      ];
    };
  };
}
