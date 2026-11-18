{ inputs, ... }:
{
  # Active ARM rips on the status page's ARM card. A helper on the status
  # page host reshapes ARM's job list for homepage and still answers while
  # the ARM host is off.
  flake.modules.nixos.armRips =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.armRips;
      arm = inputs.self.homelabServices.arm;
    in
    {
      options.armRips = {
        armUrl = lib.mkOption {
          type = lib.types.str;
          default = "http://${inputs.self.homelabHosts.${arm.host}}:${toString arm.port}";
          description = "ARM web UI, reached from this host.";
        };
        port = lib.mkOption {
          type = lib.types.port;
          default = 2285;
          description = "Local port homepage reads the job list from.";
        };
        card = lib.mkOption {
          type = lib.types.str;
          default = "arm";
          description = "Name of the healthChecks entry whose card shows the list.";
        };
      };

      config.systemd.services.arm-rips = {
        description = "ARM active rips for the status page";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        environment = {
          ARM_URL = cfg.armUrl;
          PORT = toString cfg.port;
        };
        serviceConfig = {
          ExecStart = "${lib.getExe pkgs.python3} ${./arm-rips/rips.py}";
          Restart = "on-failure";
          DynamicUser = true;
          CapabilityBoundingSet = "";
          NoNewPrivileges = true;
          PrivateDevices = true;
          PrivateTmp = true;
          ProtectHome = true;
          ProtectSystem = "strict";
          RestrictAddressFamilies = [
            "AF_INET"
            "AF_INET6"
          ];
        };
      };
    };
}
