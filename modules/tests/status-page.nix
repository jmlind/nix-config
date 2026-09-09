# Checks the aggregation logic itself: telemachus's assembled gatus config
# should contain an endpoint for every feature that registered a
# healthCheck (jellyfin, immich), each tagged with its host as `group`.
# Eval-only (no VM boot) since statusPage now reads real
# self.nixosConfigurations, not a throwaway test node.
{ self, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      endpoints = self.nixosConfigurations.telemachus.config.services.gatus.settings.endpoints;
      byName = builtins.listToAttrs (map (e: {
        name = e.name;
        value = e;
      }) endpoints);
    in
    {
      checks.status-page-wiring = pkgs.runCommand "status-page-wiring-check" { } (
        if
          (byName ? jellyfin && byName.jellyfin.group == "telemachus")
          && (byName ? immich && byName.immich.group == "telemachus")
        then
          "touch $out"
        else
          throw "expected jellyfin+immich endpoints grouped under telemachus, got: ${builtins.toJSON endpoints}"
      );
    };
}
