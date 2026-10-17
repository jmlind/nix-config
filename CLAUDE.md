# nix-config

Personal nix-darwin/NixOS flake, structured with the **dendritic pattern**:
every file is a `flake-parts` module, and every file contributes to the flake
by *merging* into shared options rather than being manually imported/wired
together in a central place.

## How it's wired

`flake.nix` is a thin bootstrap:

```nix
imports = [
  inputs.flake-parts.flakeModules.modules  # gives us flake.modules.<class>.<name>
  (inputs.import-tree ./modules)           # auto-imports every .nix file under modules/
];
```

- `import-tree` walks `./modules` and imports **every** `.nix` file it finds
  as a flake-parts module. There is no manual list of imports to maintain —
  dropping a new file into `modules/` is enough to wire it in.
- `flake-parts.flakeModules.modules` declares the `flake.modules.<class>.<name>`
  option, which is the shared namespace all the feature files write into.

## The pattern: features as named modules

Each "feature" is its own file under `modules/features/`, and it declares
itself as an entry in `flake.modules.nixos.<name>`:

```nix
# modules/features/caddy.nix
{
  flake.modules.nixos.caddy = { pkgs, config, ... }: {
    services.caddy = { ... };
  };
}
```

This is just a plain NixOS module value living at
`flake.modules.nixos.caddy` — nothing imports it yet. Because these are
independent files that only *add* an attribute to a shared set, they compose
for free: any number of feature files can exist side by side with zero
coordination between them, and each one is independently readable/deletable.

Features that need their own options (e.g. disko layout, needing a
per-host disk path) define an `options.*` block and read it via `config` —
same as any NixOS module:

```nix
# modules/features/disko-gpt-lvm.nix
{
  flake.modules.nixos.diskoGptLvm = { config, lib, ... }: {
    options.diskoConfig.primaryDisk = lib.mkOption { type = lib.types.str; };
    config.disko.devices = { ... };  # uses config.diskoConfig.primaryDisk
  };
}
```

## Hosts: opting into features

A host is where features actually get pulled together. Each host under
`modules/hosts/<name>/` has:

- `configuration.nix` — builds `flake.nixosModules.<name>Configuration` by
  `imports`-ing the feature names it wants out of `self.modules.nixos`:

  ```nix
  # modules/hosts/telemachus/configuration.nix
  flake.nixosModules.telemachusConfiguration = { pkgs, lib, ... }: {
    imports = with self.modules.nixos; [
      telemachusHardware
      jellyfin
      immich
      diskoGptLvm
      nix-settings
    ];
    diskoConfig.primaryDisk = "/dev/nvme0n1";  # host-specific option values
    system.stateVersion = "24.05";
    # ... other host-specific settings
  };
  ```

- `default.nix` — turns that module into an actual
  `flake.nixosConfigurations.<name>` via `nixpkgs.lib.nixosSystem`.
- `hardware-configuration.nix` — the standard generated hardware module,
  itself registered as a feature (`self.modules.nixos.<name>Hardware`) so it
  can be imported the same way as everything else.

So the flow per host is: **pick features by name → set host-specific option
values → build the system.** Adding a new feature to a host is a one-line
addition to that host's `imports` list; adding a brand new feature to the
repo is just a new file in `modules/features/` that nothing else has to
touch.

## Live health: one status page, aggregated across hosts

VM checks answer "does this evaluate and boot"; they say nothing about a
*running* host. For that, features self-register a health check into a
shared `healthChecks` option (`modules/features/health-endpoints.nix`), and
`modules/features/status-page.nix` collects `healthChecks` from **every**
host in `self.nixosConfigurations` — not just the host it runs on — into
one [gatus](https://github.com/TwiN/gatus) dashboard behind its own Caddy
vhost, sectioned by host via gatus's `group` field. gatus was chosen over
something like Uptime Kuma because it's configured entirely from Nix (a
plain endpoint list) rather than through its own UI/DB, so it fits a
git-checked-in flake:

```nix
# modules/features/jellyfin.nix
flake.modules.nixos.jellyfin = { ... }: {
  services.jellyfin.enable = true;
  # option declared by `healthEndpoints`, pulled in transitively by
  # whatever host also imports `statusPage` — see below
  healthChecks = [{ name = "jellyfin"; url = "http://localhost:8096/health"; }];
};
```

A host gets the *whole* dashboard — the `healthChecks` option, gatus
itself, and its Caddy vhost — from **one** import:

```nix
# modules/hosts/telemachus/configuration.nix
imports = with self.modules.nixos; [
  jellyfin immich nut-client
  statusPage  # self-imports healthEndpoints + caddy; see below
];
```

`statusPage` self-imports its two dependencies (`healthEndpoints`, `caddy`)
the same way `jellyfin` self-imports `nas-media` — the host only ever names
the one feature it actually wants. `caddy` in turn owns the
`caddy.baseDomain` option (default `lind.estate`) for the same reason
`nas-media` owns `mediaMount.group`/`mountPoint`: it's the shared primitive,
so anything else that ever fronts a vhost through `caddy` reads the same
option rather than each redeclaring its own.

Features never write Caddy config. They declare what they serve in the
neutral `webServices` option (`modules/features/web-services.nix`), e.g.
`webServices.jellyfin.port = 8096;` (`lanOnly` defaults to true). `caddy`
collects `webServices` from **every** host, like `statusPage` does with
`healthChecks`, and serves each as `<name>.<baseDomain>`, proxying to the host
that declared it (e.g. `arm` on homelab proxies to homelab's IP). Only
telemachus runs Caddy.

DNS needs no per-feature wiring either: `dns-server` reads the vhost names from
`services.caddy.virtualHosts` on every host in `self.nixosConfigurations` and
points each name at the IP of the host that defines it. Adding a vhost is
enough to get a LAN DNS record for it.

Each host's real LAN address comes from `modules/network.nix`
(`self.homelabHosts`) — `statusPage` rewrites each check's `localhost` to
that host's address, since one gatus instance now reaches every host's
services (jellyfin/immich already set `openFirewall = true`, so this works
over the LAN as-is). `healthChecks` entries are gatus endpoints — `url` can
be `http://...` (HTTP check) or `tcp://host:port` (plain connectivity
check, e.g. `dns-server`'s dnsmasq). Not every feature has a meaningful
health check to register (e.g. `nut-client` only watches a UPS elsewhere on
the network) — that's fine, it's opt-in per feature.

Adding a new host to the dashboard needs no changes to `statusPage`
itself — the moment that host has any feature registering `healthChecks`
and an entry in `self.homelabHosts`, its checks appear on telemachus's
page, grouped under its own hostname (it still needs `healthEndpoints` —
or `statusPage` — in its own imports for `healthChecks` to be a valid
option to set at all).

The dashboard is served at `status.<baseDomain>` (currently
`status.lind.estate`), kept LAN-only even though it gets a real cert:
`caddy.nix`'s porkbun DNS-01 challenge proves domain ownership without
needing 80/443 reachable from the internet, so the hostname resolves with
valid TLS while access is still gated inside Caddy (`remote_ip` matcher),
not just left to the firewall.

## Notes

- `old/` holds the pre-rewrite, non-dendritic config for reference during
  the migration — not part of the active flake.
- Prefer small, single-purpose feature files over grouping unrelated config
  together; the pattern's value comes from features being independently
  composable.
