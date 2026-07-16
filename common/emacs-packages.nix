{
  extraPackages ? [ ],
}:

epkgs:
extraPackages
++ (with epkgs; [
  alert
  cape
  consult
  corfu
  ef-themes
  gcmh
  hledger-mode
  marginalia
  nix-mode
  orderless
  org-fragtog
  org-roam
  org-roam-ui
  pdf-tools
  treesit-auto
  (treesit-grammars.with-grammars (grammars: [
    grammars.tree-sitter-typst
  ]))
  typst-preview
  typst-ts-mode
  use-package
  vertico
  visual-fill-column
  vterm
])
