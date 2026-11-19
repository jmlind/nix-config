# Secrets (sops-nix)

Secrets live encrypted in `modules/features/secrets.yaml`, encrypted with
[sops](https://github.com/getsops/sops) to the
[age](https://github.com/FiloSottile/age) recipients in `.sops.yaml`.
[sops-nix](https://github.com/Mic92/sops-nix) decrypts them on each host at
activation. Features declare the secrets they use; `sops.nix` points
sops-nix at the key file.

## One-time setup

1. Create a personal age key, so you can edit secrets from your workstation:

   ```
   age-keygen -o ~/.config/sops/age/key.txt
   ```

2. Copy that key to each host that needs secrets:

   ```
   ssh homelab@homelab.local 'sudo install -D -m 0400 -o root -g root /dev/stdin /var/lib/sops-nix/key.txt' < key.txt
   ```

## Editing

```
sops modules/features/secrets.yaml
```

## Rotating keys

After changing recipients in `.sops.yaml` (e.g. adding a separate key per
host):

```
sops updatekeys modules/features/secrets.yaml
```
