{ pkgs, ... }:
{
  # ── Steam ──────────────────────────────────────────────────────────
  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;
    remotePlay.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
  };

  # ── Lutris + Wine ──────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    (lutris.override {
      extraLibraries = pkgs: with pkgs; [
        gamemode
        mangohud
        vulkan-loader
      ];
      extraPkgs = pkgs: with pkgs; [
        wine-staging
        winetricks
        gamemode
        mangohud
        vulkan-loader
        vulkan-tools
        gnutls        # networking for Wine games
        openldap      # some multiplayer games
        libgpg-error  # crypto/auth
        sqlite        # save data
      ];
    })
    wine-staging
    winetricks
    mangohud
    protonup-qt
    vkbasalt
    vulkan-loader
    vulkan-tools
    gamescope
  ];

  # ── Gaming optimizations ───────────────────────────────────────────
  programs.gamemode.enable = true;

  # Make libgamemode.so findable by games
  environment.sessionVariables = {
    LD_LIBRARY_PATH = "${pkgs.gamemode.lib}/lib";
  };

  # Xbox controller support
  hardware.xone.enable = true;

  # Many Proton/Wine games need a higher map count
  boot.kernel.sysctl."vm.max_map_count" = 1048576;
}
