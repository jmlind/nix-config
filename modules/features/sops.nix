{ inputs, ... }: {
  flake.modules.nixos.sops = {
    # Fixed key so the module system dedupes this module: several features
    # (porkbun-secrets, nut-client) self-import it, and sops-nix's options
    # would otherwise be declared twice on the same host.
    key = "nix-config#sops";

    imports = [ inputs.sops-nix.nixosModules.sops ];

    # A dedicated per-host age key
    sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  };
}
