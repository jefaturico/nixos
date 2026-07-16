{ pkgs ? import <nixpkgs> { }, depot ? { }, ... }:

let
  emacsBuilder = depot.tools.emacs-pkgs.buildEmacsPackage or pkgs.emacs-pgtk.pkgs.trivialBuild;

  module = pkgs.rustPlatform.buildRustPackage {
    name = "libeureka";
    src = pkgs.nix-gitignore.gitignoreSource [ ] ./.;
    nativeBuildInputs = [ pkgs.pkg-config ];
    buildInputs = [ pkgs.emacs-pgtk pkgs.libxkbcommon ];
    cargoLock.lockFile = ./Cargo.lock;

    postInstall = ''
      mkdir -p $out/share/emacs/site-lisp
      ln -s $out/lib/libeureka.so $out/share/emacs/site-lisp/libeureka.so
    '';
  };
in
emacsBuilder {
  pname = "eureka";
  version = "0.1";
  src = ./lisp/eureka.el;
  packageRequires = [ module ];

}
