{ inputs, ... }:
{
  # PeaNUT: web dashboard for the NUT server that nut-client already watches.
  # Fully declared here: the container saves no settings (DISABLE_CONFIG_FILE)
  # and gets no NUT login, so it can read the UPS but never send it commands.
  flake.modules.nixos.peanut =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.peanut;
      envFile = "/run/peanut/nut.env";
    in
    {
      # healthChecks comes from statusPage (or healthEndpoints) in the host's
      # imports, like jellyfin/immich: a second import would declare it twice.
      imports = [ inputs.self.modules.nixos.containers ];

      options.peanut = {
        nutHost = lib.mkOption {
          type = lib.types.str;
          default = "pi301.local";
          description = "NUT server, resolved on this host (mDNS) at container start.";
        };
        upsName = lib.mkOption {
          type = lib.types.str;
          default = "ups";
          description = "UPS name on the NUT server, shown on the status page card.";
        };
        port = lib.mkOption {
          type = lib.types.port;
          default = inputs.self.homelabServices.peanut.port;
          description = "Host port for the PeaNUT web UI.";
        };
      };

      config = {
        # Resolve *.local names on the host. The container can't do mDNS, so
        # the host looks the NUT server up and passes the address in.
        services.avahi = {
          enable = true;
          nssmdns4 = true;
        };

        virtualisation.oci-containers.containers.peanut = {
          image = "brandawg93/peanut:6.1.2";
          ports = [ "${toString cfg.port}:8080" ];
          environment = {
            AUTH_DISABLED = "true";
            DISABLE_CONFIG_FILE = "true";
          };
          environmentFiles = [ envFile ];
        };

        # A new address on each start, so a moved Pi only needs a restart.
        # Fails (and systemd retries) while the NUT server can't be resolved.
        systemd.services.docker-peanut.wants = [ "avahi-daemon.service" ];
        systemd.services.docker-peanut.after = [ "avahi-daemon.service" ];
        systemd.services.docker-peanut.preStart = ''
          ip=$(${pkgs.getent}/bin/getent ahostsv4 ${cfg.nutHost} | ${pkgs.gawk}/bin/awk 'NR == 1 { print $1 }')
          if [ -z "$ip" ]; then
            echo "peanut: cannot resolve ${cfg.nutHost}" >&2
            exit 1
          fi
          mkdir -p ${dirOf envFile}
          echo "NUT_SERVERS=[{\"HOST\":\"$ip\",\"PORT\":3493}]" > ${envFile}
        '';

        healthChecks = [
          {
            name = "peanut";
            url = "http://localhost:${toString cfg.port}";
            icon = "peanut.png";
            description = "UPS";
            widget = {
              type = "peanut";
              url = "http://localhost:${toString cfg.port}";
              key = cfg.upsName;
            };
          }
        ];
      };
    };
}
