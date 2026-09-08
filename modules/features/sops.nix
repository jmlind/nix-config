{ inputs, ... }: {
  flake.modules.nixos.sops = {
    imports = [ inputs.sops-nix.nixosModules.sops ];

    # Decrypt with the host's own SSH host key instead of provisioning and
    # rotating a separate age key per machine.
    sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  };
}
