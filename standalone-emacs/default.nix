{
  pkgs ? import <nixpkgs> { },
  emacs ? pkgs.emacs-pgtk,
}:

let
  epkgs = pkgs.emacsPackagesFor emacs;

  # This configuration uses gptel's ChatGPT Plus/Pro OAuth backend, which is
  # newer than the gptel in some nixpkgs snapshots.  Keep this pin in sync
  # with the backend configured in lisp/jf-gptel.el.
  gptelOauth = epkgs.gptel.overrideAttrs (_old: {
    version = "0.9.9.5-unstable-2026-07-22";
    src = pkgs.fetchFromGitHub {
      owner = "karthink";
      repo = "gptel";
      rev = "8701e2bd80c5d2091ce2decef5d34d6fce4a3ada";
      hash = "sha256-RTFLoswKWkMsB1KNMtIdlcM6/LnsL5/seQHsHglFxWs=";
    };
  });
in
epkgs.emacsWithPackages (
  packages:
  with packages;
  [
    cape
    consult
    corfu
    ef-themes
    elfeed
    gcmh
    gptelOauth
    hledger-mode
    markdown-mode
    marginalia
    nix-mode
    orderless
    org-drill
    org-fragtog
    org-roam
    org-roam-ui
    typst-preview
    typst-ts-mode
    use-package
    vertico
    visual-fill-column
    vterm
  ]
  ++ pkgs.lib.optional (packages ? treesit-grammars) (
    treesit-grammars.with-grammars (grammars: [
      grammars.tree-sitter-python
      grammars.tree-sitter-typst
    ])
  )
)
