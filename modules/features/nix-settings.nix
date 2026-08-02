{
  flake.modules.nixos.nix-settings = { pkgs, config, ... }: {
    nix = {
      settings.auto-optimise-store = true;
      settings.trusted-users = [ "root" "@wheel" ];
      settings.experimental-features = [
        "nix-command"
        "flakes"
      ];
      settings.download-buffer-size = 524288000;
      gc = pkgs.lib.optionalAttrs config.nix.enable {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 7d";
      };
    };
  };
}
