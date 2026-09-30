{
  config,
  username,
  ...
}:
{
  imports = [
    ./shell.nix
    ./desktop.nix
    ./hyprland.nix
    ./theme-switch.nix
    ./editors.nix
    ./mail.nix
    ./secrets.nix
    ./packages.nix
  ];

  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    # Never change this after the install.
    stateVersion = "26.05";
  };

  # `dotfiles "emacs/init.el"` gives a symlink straight into this repo
  # instead of a read-only copy in the nix store. Two reasons: programs that
  # write to their own config keep working (emacs Custom), and edits apply
  # without a rebuild.
  #
  # The price: the repo has to live at ~/nixos.
  _module.args.dotfiles =
    path: config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/dotfiles/${path}";
}
