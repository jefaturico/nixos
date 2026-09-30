# Things you want eventually but that are not enabled yet. Each needs a
# decision or a manual step that should not happen as a side effect of the
# first install. Nothing in this file is active.
#
# Already implemented, so not here:
#   nix-direnv  -> home/shell.nix
#   nix-index   -> modules/nix.nix (database from the nix-index-database input)
#   lanzaboote  -> modules/secure-boot.nix, switched off in hosts/coriolis/default.nix
{ ... }:
{
  # ---- agenix (secrets in the repo) ----------------------------------------
  # Why not now: you chose to redo authentication by hand, and there are
  # only two mail passwords, which already live in `pass`. agenix pays off
  # once something system-level needs a secret (Wi-Fi PSKs, a user password
  # hash, a VPN key).
  #
  # To enable:
  #   1. Uncomment the agenix input in flake.nix and add
  #      `agenix.nixosModules.default` to the modules list.
  #   2. Create secrets/secrets.nix listing the public keys allowed to
  #      decrypt. The host key is /etc/ssh/ssh_host_ed25519_key.pub, which
  #      needs `services.openssh.enable = true` to exist.
  #   3. nix run github:ryantm/agenix -- -e secrets/<name>.age
  #
  # age.secrets.wifi-home.file = ../secrets/wifi-home.age;
  # users.users.jefaturico.hashedPasswordFile = config.age.secrets.password.path;

  # ---- stylix (one theme for everything) -----------------------------------
  # Why not now: stylix takes over the colours and fonts of every program it
  # knows (foot, fuzzel, mako, GTK, the console, emacs, neovim). That would
  # replace what is set by hand in home/desktop.nix and modules/console.nix,
  # so those have to be removed in the same change or the two will fight.
  #
  # To enable:
  #   1. Uncomment the stylix input in flake.nix and add
  #      `stylix.nixosModules.stylix` to the modules list.
  #   2. Uncomment the block below.
  #   3. Delete console.colors (modules/console.nix), the colour sections of
  #      foot and fuzzel (home/desktop.nix) and the GTK theme (home/desktop.nix).
  #
  # stylix = {
  #   enable = true;
  #   base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-medium.yaml";
  #   image = ../dotfiles/wallpapers/forest-fog-deer-3840x2160.jpg;
  #   polarity = "dark";
  #   fonts = {
  #     monospace = {
  #       package = pkgs.nerd-fonts.jetbrains-mono;
  #       name = "JetBrainsMono Nerd Font";
  #     };
  #     sansSerif = {
  #       package = pkgs.noto-fonts;
  #       name = "Noto Sans";
  #     };
  #     serif = {
  #       package = pkgs.noto-fonts;
  #       name = "Noto Serif";
  #     };
  #   };
  # };
}
