{ self, inputs, ... }: {

  flake.nixosModules.homelabConfiguration = { pkgs, lib, ... }: {
    # import any other modules from here
    imports = [
      self.nixosModules.myMachineHardware
    ];

    nix.settings.experimental-features = [ "nix-command" "flakes" ];
  
    # ...any other config typically in configuration.nix
  };

}
