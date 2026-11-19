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
      # Extras that appear when the host also imports the matching feature.
      # Detected with `options ?`, not imported: these modules have no key,
      # so a second import would declare their options twice.
      mediaMount = lib.optionalString (options ? mediaMount) config.mediaMount.mountPoint;

      backdrop = lib.optionalString (options ? immichBackdrop) config.immichBackdrop.url;
      rotateMinutes = 5;

      ripsWidget = lib.optionalAttrs (options ? armRips) {
        ${config.armRips.card} = {
          type = "customapi";
          url = "http://127.0.0.1:${toString config.armRips.port}/";
          display = "dynamic-list";
          refreshInterval = 10000;
          mappings = {
            items = "jobs";
            name = "title";
            label = "status";
          };
        };
      };

      # This host's own section first, then the others by name.
      ownHost = config.networking.hostName;
      hostRank = node: (if node.config.networking.hostName == ownHost then "0" else "1") + node.config.networking.hostName;
      nodes = lib.sort (a: b: hostRank a < hostRank b) (lib.attrValues self.nixosConfigurations);

      # Icons are vendored and served by homepage itself: no CDN.
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

      # One group per host. `localhost` becomes the host's LAN address,
      # since this one page checks every host.
      groups = lib.concatMap (
        node:
        let
          hostName = node.config.networking.hostName;
          checks = node.config.healthChecks or [ ];
          toService =
            hc:
            let
              toLan = lib.replaceStrings [ "localhost" ] [ self.homelabHosts.${hostName} ];
              url = toLan hc.url;
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
                // lib.optionalAttrs (hc.description != null) { inherit (hc) description; }
                // lib.optionalAttrs (hc.widget != null) {
                  widget = hc.widget // lib.optionalAttrs (hc.widget ? url) { url = toLan hc.widget.url; };
                }
                // lib.optionalAttrs (ripsWidget ? ${hc.name}) { widget = ripsWidget.${hc.name}; };
            };
        in
        lib.optional (checks != [ ]) { ${hostName} = map toService checks; }
      ) nodes;
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
        }
        // lib.optionalAttrs (backdrop != "") {
          # Dimmed and blurred so text stays readable on bright photos.
          background = {
            image = backdrop;
            blur = "sm";
            brightness = 80;
            saturate = 80;
            opacity = 45;
          };
          cardBlur = "md";
        }
        // {
          # A list, not an attrset: homepage orders sections by layout, and
          # an attrset would sort them by name.
          layout = map (name: {
            ${name} = {
              style = "row";
              columns = 3;
              icon = icon "server.svg";
            };
          }) (lib.concatMap lib.attrNames groups);
        };
        customCSS = ''
          html { font-size: 18px; }
        '';
        # Each backdrop request is a new random photo. Fetch it once as a blob
        # (a preload plus a CSS url() would be two requests, two photos), then
        # swap it into the background layer homepage draws in #background.
        customJS = lib.optionalString (backdrop != "") ''
          setInterval(async () => {
            const bg = document.getElementById("background");
            if (!bg) return;
            try {
              const res = await fetch("${backdrop}", { cache: "no-store" });
              if (!res.ok) return;
              const url = URL.createObjectURL(await res.blob());
              const old = bg.dataset.backdrop;
              bg.style.backgroundImage = bg.style.backgroundImage.replace(/url\([^)]*\)/, `url("''${url}")`);
              bg.dataset.backdrop = url;
              if (old) URL.revokeObjectURL(old);
            } catch (e) {}
          }, ${toString rotateMinutes} * 60 * 1000);
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
        };
        services = groups;
      };

      # The disk widget only sees the share once the automount has fired.
      # Wants, not Requires: a down NAS must not take the page down.
      systemd.services.homepage-dashboard.unitConfig = lib.optionalAttrs (mediaMount != "") {
        WantsMountsFor = mediaMount;
      };
    };
}
