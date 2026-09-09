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
        gid = lib.mkOption {
          type = lib.types.int;
          description = ''
            Static gid for `mediaMount.group`. Fixed (rather than left to
            NixOS's usual dynamic allocation) so it can be read at build
            time - e.g. to pass into a container via `--group-add`, which a
            container can't resolve by name since it has no matching
            /etc/group entry of its own. No default - set explicitly per
            host so it matches whatever gid the group already has on disk.
          '';
        };
      };

      config = {
        environment.systemPackages = [ pkgs.cifs-utils ];

        users.groups.${cfg.group} = { gid = cfg.gid; };

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
