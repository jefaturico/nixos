{ pkgs }:

let
  sourceRoot = ../../eureka;
  # Lisp and test edits must not invalidate the comparatively expensive native
  # build.  Include only files Cargo and the protocol generator consume.
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
    name = "libeureka";
    src = nativeSource;
    nativeBuildInputs = [ pkgs.pkg-config ];
    buildInputs = [
      pkgs.emacs-pgtk
      pkgs.libxkbcommon
    ];
    cargoLock.lockFile = nativeSource + "/Cargo.lock";

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
