{
  description = "flake parts bootstrap module for all the nix machines";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    import-tree.url = "github:vic/import-tree";
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } {
    imports = [
      # Declares flake.modules.<class>.<name> as a real, mergeable option;
      # every feature/host file below relies on it.
      inputs.flake-parts.flakeModules.modules
      (inputs.import-tree ./modules)
    ];
  };
}
