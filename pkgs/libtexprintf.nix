# Provides `utftex`, which render-markdown.nvim uses to draw LaTeX in
# Markdown buffers. Not in nixpkgs, was the AUR package libtexprintf.
{
  lib,
  stdenv,
  fetchFromGitHub,
  autoreconfHook,
  pkg-config,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "libtexprintf";
  version = "1.31";

  src = fetchFromGitHub {
    owner = "bartp5";
    repo = "libtexprintf";
    rev = "v${finalAttrs.version}";
    hash = "sha256-OXDcohfSfik0H1MpoznN267OVTYkW75N+TIF6lRRvZ0=";
  };

  nativeBuildInputs = [
    autoreconfHook
    pkg-config
  ];

  # The sources print through non-literal format strings.
  hardeningDisable = [ "format" ];

  enableParallelBuilding = true;

  meta = {
    description = "Formatted output with TeX-like syntax, as UTF-8 text";
    homepage = "https://github.com/bartp5/libtexprintf";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.linux;
    mainProgram = "utftex";
  };
})
