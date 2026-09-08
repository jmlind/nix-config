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
   age-keygen -o ~/.config/sops/age/keys.txt
   ```

   This prints an `age1...` public key.

2. **Get each host's age key**, derived from its existing SSH host key (no
   separate key to provision or rotate). Run on the host, or against a copy
   of its public key:

   ```
   nix run nixpkgs#ssh-to-age -- < /etc/ssh/ssh_host_ed25519_key.pub
   ```

3. **Fill in `.sops.yaml`** at the repo root: replace the
   `age1REPLACE_WITH_...` placeholders with the real public keys from steps
   1–2. Add one `key_groups.age` entry per host that needs to decrypt.

4. **Create the porkbun secrets file**:

   ```
   sops secrets/porkbun.yaml
   ```

   sops opens `$EDITOR` with a fresh buffer since the file doesn't exist
   yet; write:

   ```yaml
   porkbun:
       api_key: <your porkbun api key>
       api_secret_key: <your porkbun api secret key>
   ```

   Save and quit — sops encrypts the file before it ever touches disk. The
   resulting `secrets/porkbun.yaml` is ciphertext and safe to commit.

5. Deploy as usual (e.g. `nixos-rebuild switch --flake .#homelab`). sops-nix
   decrypts into `/run/secrets/...` and renders
   `/run/secrets/rendered/porkbun.env`, which Caddy picks up via
   `services.caddy.environmentFile`.

## Editing later

```
sops secrets/porkbun.yaml
```

## Adding a recipient (e.g. a new host, or rotating your personal key)

1. Add the new `age1...` key to `.sops.yaml`.
2. Re-encrypt existing files for the updated recipient list:

   ```
   sops updatekeys secrets/porkbun.yaml
   ```
