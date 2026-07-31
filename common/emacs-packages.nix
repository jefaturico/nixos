{
  extraPackages ? [ ],
}:

epkgs:
extraPackages
++ (with epkgs; [
  cape
  consult
  corfu
  ednc
  ef-themes
  elfeed
  gcmh
  hledger-mode
  markdown-mode
  marginalia
  nix-mode
  orderless
  org-fragtog
  org-roam
  org-roam-ui
  org-drill
  tabspaces
  (treesit-grammars.with-grammars (grammars: [
    grammars.tree-sitter-python
    grammars.tree-sitter-typst
  ]))
  typst-preview
  typst-ts-mode
  use-package
  vertico
  visual-fill-column
  vterm
])
