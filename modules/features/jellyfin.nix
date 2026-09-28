{ self, ... }:
{
  flake.modules.nixos.jellyfin = { pkgs, config, ... }: {
    imports = [ self.modules.nixos.nas-media ];

    users.users.jellyfin.extraGroups = [ config.mediaMount.group ];

    services.jellyfin = {
      enable = true;
      openFirewall = true;
    };

    environment.systemPackages = [
      pkgs.jellyfin
      pkgs.jellyfin-web
      pkgs.jellyfin-ffmpeg
    ];

    healthChecks = [
      {
        name = "jellyfin";
        url = "http://localhost:8096/health";
      }
    ];
  };
}
