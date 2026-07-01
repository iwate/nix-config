{ lib
, stdenv
, rustPlatform
, pkg-config
, llvmPackages
, genzo
}:

rustPlatform.buildRustPackage rec {
	pname = "genzo";
	version = "0.1.0";

	src = genzo;

	cargoLock = {
		lockFile = "${genzo}/Cargo.lock";
		outputHashes = {
			"ratatui-image-10.0.6" = "sha256-qWqXmBblpwNYSHuCwLZ8dX8vc6BAXy9f2NviUDppn70=";
		};
	};

	nativeBuildInputs = [
		pkg-config
		rustPlatform.bindgenHook
	];

	buildInputs = [
		stdenv.cc.cc
		stdenv.cc.cc.lib
		llvmPackages.libclang
	];

	doCheck = false;

	meta = with lib; {
		description = "Terminal-based RAW photo development tool";
		homepage = "https://github.com/iwate/genzo";
		license = licenses.mit;
		mainProgram = "genzo";
		platforms = platforms.linux;
	};
}
