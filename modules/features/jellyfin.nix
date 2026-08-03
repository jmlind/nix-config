{
  flake.modules.nixos.jellyfin = { pkgs, config, ... }: {
    imports = [ config.flake.modules.nixos.nas-media ];

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
  };
}
