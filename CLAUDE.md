# nix-config

Personal NixOS flake built on the **dendritic pattern**: every file is a
`flake-parts` module that merges into shared options, instead of being wired
together in one central place.

## Structure

`flake.nix` only bootstraps: `import-tree` imports every `.nix` file under
`modules/`, and `flake-parts.flakeModules.modules` provides the
`flake.modules.<class>.<name>` namespace they write into. Adding a file is
enough to wire it in.

- **Features** (`modules/features/`): one file per feature, each defining
  `flake.modules.nixos.<name>`. Features are independent and may declare
  their own options.
- **Hosts** (`modules/hosts/<name>/`): `configuration.nix` imports features
  by name and sets host-specific values; `default.nix` builds the
  `nixosConfiguration`; the hardware config is itself a feature.

So per host: pick features by name, set host values, build.

### Decisions

- Prefer small, single-purpose feature files; the pattern's value is that
  features compose independently.
- A feature imports what it depends on (e.g. `jellyfin` imports
  `nas-media`). These modules have no key, so importing one twice in the
  same host declares its options twice. Where two features share a
  dependency, the host gets it from one place (e.g. `statusPage` provides
  `healthEndpoints`), and optional integrations are detected with
  `options ? <name>` instead of imported.
- Shared facts live in one flake-level table each: `homelabHosts`
  (`modules/network.nix`, LAN addresses) and `homelabServices` plus
  `homelabDomain` (`modules/features/dns-server.nix`, web names). Fixed IPs
  over mDNS: containers can't resolve `.local`.

## Web services and DNS

telemachus runs dnsmasq and Caddy. Every name in `homelabServices`
resolves to telemachus, and Caddy proxies it to `host:port`. Adding a web
service is one line in that table.

Vhosts get real certificates through Porkbun DNS-01, so nothing needs to be
reachable from the internet. Access is still limited to the LAN inside
Caddy (`remote_ip`), not only by the firewall.

## Status page

`statusPage` (telemachus) runs a [homepage](https://gethomepage.dev)
dashboard at `status.lind.estate`. Features register entries in a shared
`healthChecks` option, and the page collects them from **every** host in
`self.nixosConfigurations`, one section per host. A new host appears on the
page once it registers checks and has an entry in `homelabHosts`.

Decisions:

- homepage replaced gatus: it shows values (NAS usage, UPS charge, active
  rips), not only up/down, and is still configured entirely from Nix.
- Icons are vendored in `status-page/icons/`; the page loads nothing from a
  CDN.
- Data homepage can't read directly goes through a small helper on
  telemachus: `armRips` (ARM's job list, and ARM's host is often off) and
  `immichBackdrop` (keeps the Immich API key out of the browser).

## Secrets

sops-nix with one age key, shared by the hosts; see `secrets.md`.

## Incus (POC)

`incus` (telemachus) runs Incus with its web UI at
`https://192.168.1.190:8443`, LAN only. It is not behind Caddy: the UI
logs in with a TLS client certificate, which a proxy would terminate.
A oneshot creates VM `poc` once from the `medium` profile (2 vCPU, 4 GiB);
after that the VM is managed in the UI, not in Nix.
