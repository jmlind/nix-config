{ self, inputs, ... }: {
  flake.nixosConfigurations.homelab = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      self.nixosModules.homelabConfiguration
    ];
  };
}
