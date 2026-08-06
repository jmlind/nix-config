{self, inputs, ... }: {

  flake.nixosModules.telemachusConfiguration = {
    # import any other modules from here
    imports = with self.modules.nixos; [
      telemachusHardware
      jellyfin
      immich
      nut-client
      nix-settings
    ];

    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];

    # ...any other config typically in configuration.nix
  };

}
