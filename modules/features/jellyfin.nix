{ self, ... }:
{
  flake.modules.nixos.jellyfin = { pkgs, config, ... }: {
    imports = [
      self.modules.nixos.nas-media
      self.modules.nixos.webServices
    ];

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

    webServices.jellyfin.port = 8096;

    healthChecks = [
      {
        name = "jellyfin";
        url = "http://localhost:8096/health";
      }
    ];
  };
}
