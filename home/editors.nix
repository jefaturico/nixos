{
  pkgs,
  dotfiles,
  ...
}:
let
  # Emacs, mu4e and the mu binary have to come from the same nixpkgs: mu4e
  # refuses to talk to a mu of another version. All three are taken from
  # unstable (emacs 31, mu 1.14). Stable is on emacs 30 and mu 1.12. `mu`
  # itself is in home/mail.nix.
  emacs = (pkgs.unstable.emacsPackagesFor pkgs.unstable.emacs-pgtk).emacsWithPackages (
    epkgs: with epkgs; [
      mu4e
      gruvbox-theme

      # Typst: the mode, and the grammar it highlights with.
      typst-ts-mode
      (treesit-grammars.with-grammars (grammars: [ grammars.tree-sitter-typst ]))
    ]
  );

  # Python with its language server. pyflakes is the only checker: it
  # reports real mistakes (syntax, undefined names, unused imports) and no
  # style or type complaints.
  python = pkgs.python3.withPackages (
    ps: [ ps.python-lsp-server ] ++ ps.python-lsp-server.optional-dependencies.pyflakes
  );
in
{
  # The config is dotfiles/emacs/init.el.
  home.file.".emacs".source = dotfiles "emacs/init.el";

  # Runs as a daemon from login, so `emacsclient` opens instantly.
  services.emacs = {
    enable = true;
    package = emacs;
    startWithUserSession = true;
  };

  home.packages = [
    emacs
    # The language servers Emacs talks to. Typst's (tinymist) is in
    # home/packages.nix, next to typst itself.
    python
  ];
}
