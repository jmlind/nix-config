{ inputs, ... }: {
  flake.modules.nixos.sops = {
    imports = [ inputs.sops-nix.nixosModules.sops ];

    # A dedicated per-host age key, independent of SSH (no ssh_host_ed25519_key
    # to depend on, no coupling to whether openssh is even enabled). Generate
    # with `age-keygen` and copy it to this path on each host — see
    # secrets/README.md.
    sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  };
}
