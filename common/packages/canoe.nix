{ pkgs }:

pkgs.rustPlatform.buildRustPackage rec {
  pname = "canoe";
  version = "0.1.1";

  src = pkgs.fetchCrate {
    inherit pname version;
    hash = "sha256-UdKHk0A58wjvKFUA4+UMoG/FQml1SIRwMj7+CJOIXOc=";
  };

  cargoLock.lockFile = "${src}/Cargo.lock";

  nativeBuildInputs = [ pkgs.pkg-config ];
  buildInputs = with pkgs; [
    fontconfig
    freetype
    libxkbcommon
  ];

  meta = {
    description = "Stacking window manager for the River compositor";
    homepage = "https://github.com/roblillack/canoe";
    license = pkgs.lib.licenses.mit;
    mainProgram = "canoe";
    platforms = pkgs.lib.platforms.linux;
  };
}
