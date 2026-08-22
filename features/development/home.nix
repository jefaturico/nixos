{
  inputs,
  pkgs,
  ...
}:

# Working on code, including on this flake: version control, the language
# servers and formatters Neovim drives, the toolchains they need, the
# rebuild helper, and the coding agents.
let
  rebuildPush = pkgs.writeScriptBin "rebuild-push" (import ./rebuild-push.nix { inherit pkgs; });

  unstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  programs.git = {
    enable = true;
    settings = {
      user.name = "jefaturico";
      user.email = "jefaturico@gmail.com";
      init.defaultBranch = "main";
      safe.directory = "/etc/nixos";
    };
  };

  home.packages = [
    rebuildPush

    # Language servers enabled in `neovim.nix`. Keep the two lists in sync.
    pkgs.lua-language-server
    pkgs.markdown-oxide
    pkgs.nil
    pkgs.ruff
    pkgs.tinymist

    # Formatters. nixfmt is the repository convention; shfmt and stylua are
    # invoked by hand, since Neovim formats through the language servers.
    pkgs.nixfmt
    pkgs.shfmt
    pkgs.stylua

    pkgs.ripgrep

    # Coding agents. Codex tracks unstable so it stays current without moving
    # the system off the stable release.
    pkgs.claude-code
    unstable.codex
    inputs.antigravity-nix.packages.${pkgs.stdenv.hostPlatform.system}.google-antigravity-cli
  ];
}
