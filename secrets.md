# Secrets (sops-nix)

Secrets are encrypted with [sops](https://github.com/getsops/sops) to
[age](https://github.com/FiloSottile/age) recipients and decrypted on-host
by [sops-nix](https://github.com/Mic92/sops-nix) at activation time. Nothing
in this directory is readable without one of the private age keys named in
`../.sops.yaml`.

Wiring lives in `modules/features/sops.nix` (generic bootstrap) and
`modules/features/porkbun-secrets.nix` (the porkbun secrets themselves,
rendered into an env file consumed by `modules/features/caddy.nix`).

## One-time setup

1. **Get a personal age key** (so you can create/edit secrets from your
   workstation):

   ```
   age-keygen -o ~/.config/sops/age/key.txt
   ```

   This prints an `age1...` public key.

2. **Ship this key to nodes that need it** 

   ```
   ssh homelab@homelab.local 'sudo install -D -m 0400 -o root -g root /dev/stdin /var/lib/sops-nix/key.txt' < key.txt
   ```

4. **Create the secrets file**:

   ```
   sops modules/features/secrets.yaml
   ```

   sops opens `$EDITOR` with a fresh buffer since the file doesn't exist
   yet; write:

   ```yaml
   key: <value>
   ```
5. Deploy as usual (e.g. `nixos-rebuild switch --flake .#homelab`). sops-nix
   decrypts into `/run/secrets/...` and renders
   `/run/secrets/rendered/porkbun.env`, which Caddy picks up via
   `services.caddy.environmentFile`.

## Editing later

```
sops modules/features/secrets.yaml
```

## Rotating keys 

   ```
   sops updatekeys modules/features/secrets.yaml 
   ```
