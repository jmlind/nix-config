{
  flake.modules.nixos.nas-media =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.mediaMount;
    in
    {
      options.mediaMount = {
        group = lib.mkOption {
          type = lib.types.str;
          default = "nas-media";
          description = "Group with access to the Mars NAS. Add this group to a user to grant it access.";
        };
        mountPoint = lib.mkOption {
          type = lib.types.str;
          default = "/mnt/media";
        };
      };

      config = {
        environment.systemPackages = [ pkgs.cifs-utils ];

        users.groups.${cfg.group} = { };

        fileSystems.${cfg.mountPoint} = {
          device = "//mars/media";
          fsType = "cifs";
          options = [
            "credentials=/etc/nixos/mars-secrets"
            "nofail"
            "noauto"
            "x-systemd.automount"
            "gid=${cfg.group}"
            "file_mode=0664"
            "dir_mode=0775"
          ];
        };
      };
    };
}
