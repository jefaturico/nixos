{
  config,
  ...
}:

let
  symlinks = {
    nvim = "nvim";
    niri = "niri";
  };
in
{
  imports = [
    ./scripts.nix
    ./programs.nix
    ./services.nix
    ./session.nix
    ./wallust.nix
  ];

  home = {
    username = "jefaturico";
    homeDirectory = "/home/jefaturico";
    stateVersion = "25.11";

    file = {
      ".config/moxide/settings.toml".text = ''
        heading_completions = false
        title_headings = false
        link_filenames_only = true
      '';
      ".latexmkrc".text = ''
        $pdf_previewer = 'zathura';
        $pdf_update_method = 0;
      '';
    }
    // (
      # Automatically symlink directories in ./dots/ to ~/.config/
      # We use mkOutOfStoreSymlink so that changes to files in the git repo
      # are immediately reflected without needing a 'nixos-rebuild switch'.
      builtins.listToAttrs (
        map (name: {
          name = ".config/${name}";
          value = {
            source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/dots/${symlinks.${name}}";
          };
        }) (builtins.attrNames symlinks)
      )
    );

  };

}
