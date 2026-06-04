{ pkgs, lib, ... }:
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
    lutris
    wine-staging
    winetricks
    mangohud
    protonup-qt
    vkbasalt
    vulkan-loader
    vulkan-tools
    gamescope
    vesktop
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
