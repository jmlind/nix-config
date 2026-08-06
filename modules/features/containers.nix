{
  flake.modules.nixos.containers = {
    # Docker for containers
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

