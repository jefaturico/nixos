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
      extraLibraries =
        pkgs: with pkgs; [
          gamemode
          mangohud
          vulkan-loader
        ];
      extraPkgs =
        pkgs: with pkgs; [
          wine-staging
          winetricks
          gamemode
          mangohud
          vulkan-loader
          vulkan-tools
          gnutls # networking for Wine games
          openldap # some multiplayer games
          libgpg-error # crypto/auth
          sqlite # save data
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

  # Intel Specific Optimizations
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-media-driver
      intel-vaapi-driver
      libvdpau-va-gl
    ];
  };

  # Process prioritization
  services.ananicy = {
    enable = true;
    package = pkgs.ananicy-cpp;
    rulesProvider = pkgs.ananicy-rules-cachyos;
  };
}
