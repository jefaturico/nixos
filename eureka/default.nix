{
  pkgs ? import <nixpkgs> { },
  emacs ? pkgs.emacs-pgtk,
}:

let
  sourceRoot = ./.;
  nativeSource = pkgs.lib.fileset.toSource {
    root = sourceRoot;
    fileset = pkgs.lib.fileset.unions [
      (sourceRoot + "/Cargo.lock")
      (sourceRoot + "/Cargo.toml")
      (sourceRoot + "/protocol")
      (sourceRoot + "/src")
    ];
  };

  module = pkgs.rustPlatform.buildRustPackage {
    pname = "libeureka";
    version = "0.1.0";
    src = nativeSource;
    nativeBuildInputs = [ pkgs.pkg-config ];
    buildInputs = [
      emacs
      pkgs.libxkbcommon
    ];
    cargoLock.lockFile = nativeSource + "/Cargo.lock";

    postInstall = ''
      mkdir -p $out/share/emacs/site-lisp
      ln -s $out/lib/libeureka.so $out/share/emacs/site-lisp/libeureka.so
    '';
  };
in
(pkgs.emacsPackagesFor emacs).trivialBuild {
  pname = "eureka";
  version = "0.1.0";
  src = sourceRoot + "/lisp/eureka.el";
  packageRequires = [ module ];
}
