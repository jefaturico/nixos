{
  lib,
  stdenv,
  fetchFromGitHub,
  libxkbcommon,
  wayland,
  wayland-scanner,
}:

stdenv.mkDerivation {
  pname = "jrwm";
  version = "0-unstable-2026-06-28";

  src = fetchFromGitHub {
    owner = "jpco";
    repo = "jrwm";
    rev = "15744801fe42b4fd95d5c9fa7931bf75f679f3ee";
    hash = "sha256-wgQMc21n5d5pNEupe6APZMwEATtbdJycznOgx1Xqnds=";
  };

  nativeBuildInputs = [ wayland-scanner ];
  buildInputs = [
    libxkbcommon
    wayland
  ];

  postPatch = ''
    substituteInPlace Makefile \
      --replace-fail '/usr/bin/install' 'install' \
      --replace-fail '/usr/bin/mkdir' 'mkdir'

    # Match the emergency bindings and launcher used by the Eureka session.
    substituteInPlace config.c \
      --replace-fail 'static char *spawn_rofi[] = {"rofi", "-show", "combi", NULL};' \
        'static char *spawn_fuzzel[] = {"fuzzel", NULL};' \
      --replace-fail '{super,       XKB_KEY_q, binding_close,' \
        '{super,       XKB_KEY_w, binding_close,' \
      --replace-fail 'spawn_binding(super, XKB_KEY_Return, spawn_foot),' \
        'spawn_binding(super|shift, XKB_KEY_Return, spawn_foot),' \
      --replace-fail 'spawn_binding(super, XKB_KEY_space,  spawn_rofi),' \
        'spawn_binding(super, XKB_KEY_space,  spawn_fuzzel),'
  '';

  makeFlags = [
    "CC=${stdenv.cc.targetPrefix}cc"
    "PREFIX=$(out)"
  ];

  meta = {
    description = "Small dynamic tiling window manager for the River compositor";
    homepage = "https://github.com/jpco/jrwm";
    license = lib.licenses.gpl3Plus;
    mainProgram = "jrwm";
    platforms = lib.platforms.linux;
  };
}
