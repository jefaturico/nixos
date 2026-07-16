{ pkgs }:

let
  sourceRoot = ../../eureka;
  # Local Rust checks create a large target/ tree.  Never copy those build
  # artifacts into the Nix source; .gitignore is the single exclusion list.
  src = pkgs.nix-gitignore.gitignoreSource [ ] sourceRoot;

  module = pkgs.rustPlatform.buildRustPackage {
    name = "libeureka";
    inherit src;
    nativeBuildInputs = [ pkgs.pkg-config ];
    buildInputs = [
      pkgs.emacs-pgtk
      pkgs.libxkbcommon
    ];
    cargoLock.lockFile = src + "/Cargo.lock";

    postInstall = ''
      mkdir -p $out/share/emacs/site-lisp
      ln -s $out/lib/libeureka.so $out/share/emacs/site-lisp/libeureka.so
    '';
  };
in
(pkgs.emacsPackagesFor pkgs.emacs-pgtk).trivialBuild {
  pname = "eureka";
  version = "0.1";
  src = sourceRoot + "/lisp/eureka.el";
  packageRequires = [ module ];
}
