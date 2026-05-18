{ lib
, rustPlatform
, pkg-config
, ffmpeg
, srt
, libv4l
, llvmPackages
, srtcamSrc
}:

rustPlatform.buildRustPackage rec {
  pname = "srtcam";
  version = "0.1.0";

  src = srtcamSrc;

  cargoLock.lockFile = "${srtcamSrc}/Cargo.lock";

  nativeBuildInputs = [
    pkg-config
    rustPlatform.bindgenHook
  ];

  buildInputs = [
    ffmpeg
    srt
    libv4l
    llvmPackages.libclang
  ];

  # ffmpeg-sys uses bindgen and expects ffmpeg headers.
  BINDGEN_EXTRA_CLANG_ARGS = "-I${ffmpeg.dev}/include";

  meta = with lib; {
    description = "SRT listener to v4l2loopback bridge";
    homepage = "https://github.com/iwate/srtcam";
    license = licenses.mit;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
