# Checks the self-registration wiring itself: a VM importing jellyfin +
# statusPage should come up with gatus running and jellyfin's healthCheck
# already present in its config, with no host-specific glue.
{ self, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      checks.status-page = pkgs.testers.nixosTest {
        name = "status-page";

        nodes.machine = {
          imports = [
            self.modules.nixos.jellyfin
            self.modules.nixos.statusPage
          ];
        };

        testScript = ''
          machine.wait_for_unit("gatus.service")
          machine.wait_for_open_port(8080)
          machine.succeed("curl -sf http://localhost:8080/api/v1/endpoints/statuses | grep -q jellyfin")
        '';
      };
    };
}
