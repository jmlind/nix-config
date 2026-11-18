{
  flake.modules.nixos.containers = {
    virtualisation = {
      docker = {
        enable = true;
        autoPrune = {
          enable = true;
          dates = "weekly";
        };
      };
      oci-containers.backend = "docker";
    };
  };
}

