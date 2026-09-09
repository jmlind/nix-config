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

## Testing: VM checks

Tests live under `modules/tests/` and are ordinary flake-parts modules too —
`import-tree` picks them up the same way it picks up features and hosts.
Each one contributes a `pkgs.testers.nixosTest` to `perSystem.checks.<name>`:

```nix
# modules/tests/jellyfin.nix
{ self, ... }: {
  perSystem = { pkgs, ... }: {
    checks.jellyfin = pkgs.testers.nixosTest {
      name = "jellyfin";
      nodes.machine = { imports = [ self.modules.nixos.jellyfin ]; };
      testScript = ''
        machine.wait_for_unit("jellyfin.service")
        machine.wait_for_open_port(8096)
      '';
    };
  };
}
```

Run everything with `nix flake check`, or one check at a time with
`nix build .#checks.x86_64-linux.<name> -L`.

- Prefer **feature-level** tests like the example above: import just the one
  `self.modules.nixos.<feature>` into a throwaway VM and assert the service
  behaves. Cheap and isolated, and there's no reason every feature can't get
  one eventually.
- A **host-level** smoke test (booting `self.nixosModules.<host>Configuration`
  itself) is more work: `telemachus`/`homelab` import real hardware modules
  and `disko`, which assume physical disks and won't boot as-is in a VM —
  that config needs to be substituted or stripped for the test node.
- `flake.nix` declares `systems = [ "x86_64-linux" ];` so `perSystem` (and
  thus `checks`) is available — add more systems here if a feature (e.g.
  `arm.nix`) needs testing on another architecture.

## Live health: one status page, aggregated across hosts

VM checks answer "does this evaluate and boot"; they say nothing about a
*running* host. For that, features self-register a health check into a
shared `healthChecks` option (`modules/features/health-endpoints.nix`), and
`modules/features/status-page.nix` collects `healthChecks` from **every**
host in `self.nixosConfigurations` — not just the host it runs on — into
one [gatus](https://github.com/TwiN/gatus) dashboard, sectioned by host via
gatus's `group` field. gatus was chosen over something like Uptime Kuma
because it's configured entirely from Nix (a plain endpoint list) rather
than through its own UI/DB, so it fits a git-checked-in flake:

```nix
# modules/features/jellyfin.nix
flake.modules.nixos.jellyfin = { ... }: {
  services.jellyfin.enable = true;
  # option declared by `healthEndpoints`, not here — see note below
  healthChecks = [{ name = "jellyfin"; url = "http://localhost:8096/health"; }];
};
```

**Important asymmetry, learned the hard way:** a feature that *sets*
`healthChecks` (jellyfin, immich, dns-server) needs `healthEndpoints` (the
module that does `options.healthChecks = lib.mkOption { ... };`) somewhere
in its host's import list — but `statusPage` deliberately does **not**
import `healthEndpoints` itself. Early on it did, and combining it with two
health-registering features on the same host (jellyfin + immich on
telemachus) failed with "already declared" — NixOS does not dedupe repeated
*option declarations* the way it dedupes plain config, so anything that
does `options.foo = lib.mkOption {...}` can only be imported from **one**
place per host. `statusPage` doesn't need it anyway: it never reads/writes
`config.healthChecks` on its own module, only `self.nixosConfigurations.*
.config.healthChecks` from the outside (`or [ ]`-guarded, since a host that
never imported `healthEndpoints` — e.g. `homelab` — has no such option at
all). So: **every host that sets `healthChecks` imports `healthEndpoints`
directly** (see `telemachus`); `statusPage` is imported on exactly one host
— whichever will actually run the dashboard:

```nix
# modules/hosts/telemachus/configuration.nix
imports = with self.modules.nixos; [
  jellyfin immich nut-client
  healthEndpoints  # because jellyfin/immich set healthChecks below
  statusPage       # runs the *unified* dashboard for every host, not just this one
  caddy statusProxy
];
```

Each host's real LAN address comes from `modules/network.nix`
(`self.homelabHosts`) — `statusPage` rewrites each check's `localhost` to
that host's address, since one gatus instance now reaches every host's
services (jellyfin/immich already set `openFirewall = true`, so this
works over the LAN as-is). `healthChecks` entries are gatus endpoints —
`url` can be `http://...` (HTTP check) or `tcp://host:port` (plain
connectivity check, e.g. `dns-server`'s dnsmasq). Not every feature has a
meaningful health check to register (e.g. `nut-client` only watches a UPS
elsewhere on the network) — that's fine, it's opt-in per feature.

Adding a new host to the dashboard needs no changes to `statusPage`
itself — the moment that host has any feature registering `healthChecks`
(plus `healthEndpoints` in its own imports, and an entry in
`self.homelabHosts`), its checks appear on telemachus's page, grouped
under its own hostname.

## Reverse proxy for the status page

`modules/features/status-proxy.nix` fronts the one unified `statusPage`
with Caddy at `status.<baseDomain>`, kept LAN-only even though it gets a
real cert: `caddy.nix`'s porkbun DNS-01 challenge proves domain ownership
without needing 80/443 reachable from the internet, so the hostname
resolves with valid TLS while access is still gated inside Caddy
(`remote_ip` matcher), not just left to the firewall. Import `caddy` and
`statusProxy` only on the host running `statusPage` (currently telemachus).

`homelab.baseDomain` (declared in `status-proxy.nix`) defaults to
`lind.estate`. One thing still to fix before this actually works:
`caddy.nix`'s plugin build has `hash = "";` — a genuine placeholder nixpkgs
expects you to fill in from the real build error (`nix build` will report
the correct hash) before caddy can build for *any* host, not just this one.

## Notes

- `old/` holds the pre-rewrite, non-dendritic config for reference during
  the migration — not part of the active flake.
- Prefer small, single-purpose feature files over grouping unrelated config
  together; the pattern's value comes from features being independently
  composable.
