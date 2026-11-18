{ inputs, ... }: {
  flake.modules.nixos.diskoGptLvm =
    { config, lib, ... }:
    let
      cfg = config.diskoConfig;
    in
    {
      options.diskoConfig.primaryDisk = lib.mkOption {
        type = lib.types.str;
        description = "Primary disk for the GPT + LVM disko layout.";
      };

      imports = [ inputs.disko.nixosModules.disko ];

      config.disko.devices = {
        disk.disk1 = {
          device = cfg.primaryDisk;
          type = "disk";
          content = {
            type = "gpt";
            partitions = {
              boot = {
                name = "boot";
                size = "1M";
                type = "EF02";
              };
              esp = {
                name = "ESP";
                size = "500M";
                type = "EF00";
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot";
                };
              };
              root = {
                name = "root";
                size = "100%";
                content = {
                  type = "lvm_pv";
                  vg = "pool";
                };
              };
            };
          };
        };
        lvm_vg.pool = {
          type = "lvm_vg";
          lvs.root = {
            size = "100%FREE";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
              mountOptions = [ "defaults" ];
            };
          };
        };
      };
    };
}
