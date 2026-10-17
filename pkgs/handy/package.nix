{
  appimage-run,
  alsa-lib,
  fetchurl,
  writeShellApplication,
}:

let
  version = "0.9.8";
  appImage = fetchurl {
    name = "Handy_${version}_amd64.AppImage";
    url = "https://github.com/cjpais/Handy/releases/download/v${version}/Handy_${version}_amd64.AppImage";
    hash = "sha256-1oPclnYvmkeXUEWrSAOS0zpbSRlo+zNtysR+L2XnGE8=";
  };
  appimageRunWithAlsa = appimage-run.override {
    extraPkgs = pkgs: [ alsa-lib ];
  };
in
writeShellApplication {
  name = "handy";
  runtimeInputs = [ appimageRunWithAlsa ];
  text = ''
    exec appimage-run ${appImage} "$@"
  '';
  meta = {
    description = "Handy speech-to-text desktop application";
    homepage = "https://github.com/cjpais/Handy";
    mainProgram = "handy";
    platforms = [ "x86_64-linux" ];
  };
}