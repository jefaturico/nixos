{ lib, stdenv, zig_0_16, wayland, pkg-config, libxkbcommon, wayland-protocols, wayland-scanner, rillSource }:

let
  # Fixed-output derivation to fetch Zig dependencies
  rill-deps = stdenv.mkDerivation {
    pname = "rill-deps";
    inherit (stdenv.hostPlatform) system;
    version = "0.5.0";
    src = rillSource;
    nativeBuildInputs = [ zig_0_16.hook ];
    dontConfigure = true;
    dontInstall = true;
    buildPhase = ''
      mkdir -p $out
      export ZIG_GLOBAL_CACHE_DIR=$out
      zig build --fetch
    '';
    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "sha256-AFp7jdvj2Qg1x33tGmmmbMcbeNpnHa9Xkr6eeYz5M7E=";
  };
in
stdenv.mkDerivation {
  pname = "rill";
  version = "0.5.0";

  src = rillSource;

  nativeBuildInputs = [
    zig_0_16.hook
    pkg-config
    wayland
    wayland-scanner
  ];

  buildInputs = [
    wayland
    libxkbcommon
    wayland-protocols
  ];

  # Use the pre-fetched dependencies
  preBuild = ''
    export ZIG_GLOBAL_CACHE_DIR=$TMPDIR/zig-cache
    mkdir -p $ZIG_GLOBAL_CACHE_DIR
    if [ -d ${rill-deps}/p ]; then
      cp -r ${rill-deps}/p $ZIG_GLOBAL_CACHE_DIR/
      chmod -R +w $ZIG_GLOBAL_CACHE_DIR
    fi
  '';

  meta = with lib; {
    description = "A minimalist scrolling window manager for river";
    homepage = "https://codeberg.org/lzj15/rill";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
