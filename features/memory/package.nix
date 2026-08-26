{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  nodejs,
}:

# Yanki is published as a tsdown bundle: `dist/bin/cli.js` is one 3MB file
# that imports nothing but Node builtins, so there is no dependency tree to
# reproduce and none of the npm machinery is needed. The upstream repo locks
# with pnpm, which `buildNpmPackage` cannot read anyway -- taking the
# registry tarball sidesteps that question entirely.
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "yanki";
  version = "2.0.14";

  src = fetchurl {
    url = "https://registry.npmjs.org/yanki/-/yanki-${finalAttrs.version}.tgz";
    hash = "sha256-POu6BOA6oE5gUKg9leMVWzHkLp4XPvMoZTXgrD3lXRk=";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/yanki
    cp -r dist package.json $out/lib/yanki/

    # package.json travels with dist because the bundle is ESM and Node
    # decides that from the nearest `"type": "module"`, not from the file.
    makeWrapper ${lib.getExe nodejs} $out/bin/yanki \
      --add-flags $out/lib/yanki/dist/bin/cli.js

    runHook postInstall
  '';

  meta = {
    description = "Turn Markdown into Anki flashcards";
    homepage = "https://github.com/kitschpatrol/yanki";
    license = lib.licenses.mit;
    mainProgram = "yanki";
    platforms = lib.platforms.all;
  };
})
