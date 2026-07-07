# Wraps a `python.withPackages` environment containing Plover and the
# selected plugins, exposing only the Plover-related executables to avoid
# installation collisions with the rest of the Python environment.
# Adapted from https://github.com/NixOS/nixpkgs/pull/518828
{
  lib,
  stdenvNoCC,
  makeWrapper,
  python,
}:

selectPlugins: # a function such as (ps: with ps; [ plugin names ])
let
  inherit (python.pkgs) plover;
  pythonEnv = python.withPackages (ps: [ ps.plover ] ++ selectPlugins ps);
in
stdenvNoCC.mkDerivation {
  pname = "plover-with-plugins";
  inherit (plover) version;

  nativeBuildInputs = [ makeWrapper ];

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin"
    for prog in ${lib.getBin plover}/bin/*; do
      makeWrapper "${lib.getBin pythonEnv}/bin/$(basename "$prog")" "$out/bin/$(basename "$prog")"
    done
  ''
  + lib.optionalString stdenvNoCC.hostPlatform.isLinux ''
    mkdir -p "$out/share/applications"
    ln -s "${plover}/share/icons" "$out/share/icons"
    substitute "${plover}/share/applications/plover.desktop" "$out/share/applications/plover.desktop" \
      --replace-fail "${plover}/bin/plover" "$out/bin/plover"
  ''
  + lib.optionalString stdenvNoCC.hostPlatform.isDarwin ''
    APP_DIR="$out/Applications/Plover.app/Contents"
    mkdir -p "$APP_DIR/MacOS" "$APP_DIR/Resources"
    ln -s "${plover}/Applications/Plover.app/Contents/Info.plist" "$APP_DIR/Info.plist"
    ln -s "${plover}/Applications/Plover.app/Contents/Resources/plover.icns" "$APP_DIR/Resources/plover.icns"
    makeWrapper "$out/bin/plover" "$APP_DIR/MacOS/Plover"
  ''
  + ''
    runHook postInstall
  '';

  passthru = {
    inherit pythonEnv;
  };

  meta = {
    mainProgram = "plover";
  };
}
