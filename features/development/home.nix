{
  inputs,
  pkgs,
  ...
}:

# Version control and the coding agents. No language servers or formatters
# live here: Neovim carries no plugins, the agents bring their own tooling,
# and the one server there is reason to run -- tinymist -- belongs with the
# documents it is for, in features/typesetting.
let
  unstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  programs.git = {
    enable = true;
    settings = {
      user.name = "jefaturico";
      user.email = "jefaturico@gmail.com";
      init.defaultBranch = "main";
    };
  };

  # Codex tracks unstable so it stays current without moving the system off
  # the stable release.
  home.packages = [
    pkgs.claude-code
    unstable.codex
    inputs.antigravity-nix.packages.${pkgs.stdenv.hostPlatform.system}.google-antigravity-cli
  ];
}
