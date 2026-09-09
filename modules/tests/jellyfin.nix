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
