{ inputs, ... }:
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
      imports = [ inputs.self.modules.nixos.sops ];

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
          default = 2100;
          description = ''
            Static gid for `mediaMount.group`. Fixed so it can be read at build
            time. 
          '';
        };
      };

      config = {
        environment.systemPackages = [ pkgs.cifs-utils ];

        sops.secrets."mars_username".sopsFile = ./secrets.yaml;
        sops.secrets."mars_password".sopsFile = ./secrets.yaml;
        # mount.cifs credentials file format
        sops.templates."mars-credentials".content = ''
          username=${config.sops.placeholder."mars_username"}
          password=${config.sops.placeholder."mars_password"}
        '';

        users.groups.${cfg.group} = { gid = cfg.gid; };

        fileSystems.${cfg.mountPoint} = {
          device = "//mars/media";
          fsType = "cifs";
          options = [
            "credentials=${config.sops.templates."mars-credentials".path}"
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
