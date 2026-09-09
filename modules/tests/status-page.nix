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
