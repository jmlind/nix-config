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

## Live health: self-registering status page

VM checks answer "does this evaluate and boot"; they say nothing about a
*running* host. For that, features self-register a health check into a
shared `healthChecks` option (`modules/features/health-endpoints.nix`), and
`modules/features/status-page.nix` turns whatever a host's imported
features registered into a [gatus](https://github.com/TwiN/gatus) status
page — chosen over something like Uptime Kuma because gatus is configured
entirely from Nix (a plain endpoint list) rather than through its own UI/DB,
so it fits a git-checked-in flake:

```nix
# modules/features/jellyfin.nix
flake.modules.nixos.jellyfin = { ... }: {
  imports = [ self.modules.nixos.healthEndpoints ];  # pulls in the option
  services.jellyfin.enable = true;
  healthChecks = [{ name = "jellyfin"; url = "http://localhost:8096/health"; }];
};
```

A feature that registers a check imports `healthEndpoints` itself (imports
dedupe, so this is free) rather than relying on the host to remember to —
same self-sufficiency as any other feature. A host gets a dashboard by
importing `statusPage`; it will show exactly the checks its *other* imported
features registered, with zero host-specific wiring:

```nix
imports = with self.modules.nixos; [ jellyfin immich nut-client statusPage ];
```

`healthChecks` entries are gatus endpoints — `url` can be `http://...` (HTTP
check) or `tcp://host:port` (plain connectivity check, e.g. for a
non-HTTP service like `dns-server`'s dnsmasq). `statusPage` currently just
opens gatus's port (8080) on the firewall; putting it behind `caddy` for
real exposure is a follow-up, not done yet. Not every feature has a
meaningful health check to register (e.g. `nut-client` only watches a UPS
elsewhere on the network) — that's fine, it's opt-in per feature.

## Notes

- `old/` holds the pre-rewrite, non-dendritic config for reference during
  the migration — not part of the active flake.
- Prefer small, single-purpose feature files over grouping unrelated config
  together; the pattern's value comes from features being independently
  composable.
