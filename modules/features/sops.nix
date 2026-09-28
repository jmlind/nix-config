{ inputs, ... }: {
  flake.modules.nixos.sops = {
    imports = [ inputs.sops-nix.nixosModules.sops ];

    # A dedicated per-host age key
    sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  };
}
