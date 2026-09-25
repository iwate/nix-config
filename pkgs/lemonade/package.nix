{ lib
, stdenvNoCC
, fetchurl
, autoPatchelfHook
, dpkg
, libdrm
, katex
, openssl
, stdenv
, zlib
, zstd
}:

let
  serverPackage = fetchurl {
    url = "https://github.com/lemonade-sdk/lemonade/releases/download/v2026.39.1/lemonade-server_2026.39.1-debian13_amd64.deb";
    sha256 = "cf68457d9a046ba376f3d5363f91a2d81769c9ec8aadb69f1bcfe249b6d7e227";
  };
in
stdenvNoCC.mkDerivation rec {
  pname = "lemonade-server";
  version = "2026.39.1";

  src = fetchurl {
    url = "https://github.com/lemonade-sdk/lemonade/releases/download/v${version}/lemonade-embeddable-${version}-ubuntu-x64.tar.gz";
    sha256 = "d93c8c726a2c27aa7dee92db9d26f8042cf4e93a67b9c6ca8def094da15bf92a";
  };

  sourceRoot = "lemonade-embeddable-${version}-ubuntu-x64";

  nativeBuildInputs = [ autoPatchelfHook dpkg ];
  buildInputs = [
    libdrm
    openssl
    stdenv.cc.cc.lib
    zlib
    zstd
  ];

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin" "$out/share/lemonade-server"
    tar -xzf "$src" --strip-components=1 -C "$out/bin"
    dpkg-deb -x ${serverPackage} debian-package
    rm -rf "$out/bin/resources"
    cp -r debian-package/usr/share/lemonade-server/resources "$out/share/lemonade-server/resources"
    ln -s ../share/lemonade-server/resources "$out/bin/resources"
    mkdir -p "$out/share/fonts/truetype/katex"
    cp -r ${katex}/lib/node_modules/katex/dist/fonts/. "$out/share/fonts/truetype/katex/"
    install -Dm755 lemond "$out/bin/lemond"
    install -Dm755 lemonade "$out/bin/lemonade"
    runHook postInstall
  '';

  meta = {
    description = "Local AI server for AMD GPUs and NPUs";
    homepage = "https://github.com/lemonade-sdk/lemonade";
    license = lib.licenses.asl20;
    platforms = [ "x86_64-linux" ];
    mainProgram = "lemonade";
  };
}