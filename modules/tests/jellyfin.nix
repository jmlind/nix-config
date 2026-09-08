# Example feature-level VM test: boots a minimal VM importing just the
# jellyfin feature module and checks the service comes up and is reachable.
#
# Run with: nix build .#checks.x86_64-linux.jellyfin -L
# (or `nix flake check` to run every check in modules/tests/)
{ self, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      checks.jellyfin = pkgs.testers.nixosTest {
        name = "jellyfin";

        nodes.machine = {
          imports = [ self.modules.nixos.jellyfin ];
        };

        testScript = ''
          machine.wait_for_unit("jellyfin.service")
          machine.wait_for_open_port(8096)
        '';
      };
    };
}
