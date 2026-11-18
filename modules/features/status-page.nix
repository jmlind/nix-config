{ self, lib, ... }:
{
  flake.modules.nixos.statusPage =
    {
      config,
      options,
      pkgs,
      ...
    }:
    let
      domain = self.homelabDomain;
      # Disk widget for the NAS share when this host mounts it (nas-media,
      # e.g. via jellyfin). Not imported here: nas-media has no module key,
      # so a second import would declare its options twice.
      mediaMount = lib.optionalString (options ? mediaMount) config.mediaMount.mountPoint;

      # Icons live in the repo (./status-page/icons) and are served by
      # homepage itself from /icons/<file>, so the page loads no CDN assets.
      iconDir = ./status-page/icons;
      icon =
        file:
        assert lib.assertMsg (builtins.pathExists (iconDir + "/${file}"))
          "status-page: no icon ${file} in modules/features/status-page/icons";
        "/icons/${file}";

      # The nixpkgs package without its CDN icon fallback: same build, with
      # public/icons replaced by the repo's icons. server.js is copied, not
      # symlinked, because node resolves a symlinked entry point to its real
      # path, and next serves public/ next to that path.
      package =
        let
          base = pkgs.homepage-dashboard;
          app = "${base}/share/homepage";
        in
        pkgs.runCommand "homepage-dashboard-local-icons"
          {
            nativeBuildInputs = [ pkgs.makeBinaryWrapper ];
            meta.mainProgram = "homepage";
          }
          ''
            mkdir -p $out/bin $out/share/homepage/public/icons
            for f in ${app}/.next ${app}/*; do
              case "$(basename "$f")" in public|server.js) ;; *) ln -s "$f" $out/share/homepage/ ;; esac
            done
            cp ${app}/server.js $out/share/homepage/server.js
            for f in ${app}/public/*; do
              [ "$(basename "$f")" = icons ] || ln -s "$f" $out/share/homepage/public/
            done
            cp ${iconDir}/*.png ${iconDir}/*.svg $out/share/homepage/public/icons/

            makeWrapper ${lib.getExe pkgs.nodejs} $out/bin/homepage \
              --set-default PORT 3000 \
              --set-default HOMEPAGE_CONFIG_DIR /var/lib/homepage-dashboard \
              --set-default NIXPKGS_HOMEPAGE_CACHE_DIR /var/cache/homepage-dashboard \
              --add-flags $out/share/homepage/server.js \
              --prefix PATH : ${lib.makeBinPath [ pkgs.unixtools.ping ]}
          '';

      # One homepage group per host, holding that host's healthChecks.
      # `localhost` becomes the host's LAN address, since this one page
      # checks every host's services.
      groups = lib.concatMap (
        node:
        let
          hostName = node.config.networking.hostName;
          checks = node.config.healthChecks or [ ];
          toService =
            hc:
            let
              url = lib.replaceStrings [ "localhost" ] [ self.homelabHosts.${hostName} ] hc.url;
            in
            {
              ${hc.name} =
                (
                  if lib.hasPrefix "tcp://" url then
                    { ping = lib.head (lib.splitString ":" (lib.removePrefix "tcp://" url)); }
                  else
                    { siteMonitor = url; }
                )
                // lib.optionalAttrs (self.homelabServices ? ${hc.name}) {
                  href = "https://${hc.name}.${domain}";
                }
                // lib.optionalAttrs (hc.icon != null) { icon = icon hc.icon; }
                // lib.optionalAttrs (hc.description != null) { inherit (hc) description; };
            };
        in
        lib.optional (checks != [ ]) { ${hostName} = map toService checks; }
      ) (lib.attrValues self.nixosConfigurations);
    in
    {
      imports = [
        self.modules.nixos.healthEndpoints
        self.modules.nixos.caddy
      ];

      services.homepage-dashboard = {
        enable = true;
        inherit package;
        listenPort = self.homelabServices.status.port;
        # caddy forwards the original Host header
        allowedHosts = "status.${domain},localhost:${toString self.homelabServices.status.port}";
        settings = {
          title = domain;
          theme = "dark";
          color = "slate";
          headerStyle = "boxed";
          statusStyle = "dot";
          useEqualHeights = true;
          hideVersion = true;
          layout = lib.genAttrs (lib.concatMap lib.attrNames groups) (_: {
            style = "row";
            columns = 3;
            icon = icon "server.svg";
          });
        };
        customCSS = ''
          html { font-size: 18px; }
        '';
        widgets = [
          {
            greeting = {
              text_size = "xl";
              text = domain;
            };
          }
          {
            datetime = {
              text_size = "md";
              format = {
                dateStyle = "long";
                timeStyle = "short";
                hour12 = false;
              };
            };
          }
          {
            resources = {
              label = config.networking.hostName;
              cpu = true;
              memory = true;
            };
          }
        ]
        ++ lib.optional (mediaMount != "") {
          resources = {
            label = "NAS media";
            disk = mediaMount;
            expanded = true;
          };
        }
        ++ [
          {
            search = {
              provider = "duckduckgo";
              target = "_blank";
            };
          }
        ];
        services = groups;
      };

      # The disk widget only sees the share once the automount has fired.
      # Wants, not Requires: a down NAS must not take the page down.
      systemd.services.homepage-dashboard.unitConfig = lib.optionalAttrs (mediaMount != "") {
        WantsMountsFor = mediaMount;
      };
    };
}
