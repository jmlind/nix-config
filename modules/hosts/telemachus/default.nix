{ self, inputs, ... }: {
  flake.nixosConfigurations.telemachus = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      self.nixosModules.telemachusConfiguration
    ];
  };
}
