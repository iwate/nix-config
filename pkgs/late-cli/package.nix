{ lib
, buildGoModule
, fetchFromGitHub
}:

buildGoModule rec {
	pname = "late-cli";
	version = "1.5.1";

	src = fetchFromGitHub {
		owner = "mlhher";
		repo = "late-cli";
		rev = "v${version}";
		hash = "sha256-a6AmX8oTlA5RgxE8dxd9OwTyadhdBGJNYzXEcJM7fWw=";
	};

	vendorHash = "sha256-C+6yPl/8XGvx+/Hk8kVussIQPE9ggPdfTyTORuiphWc=";

	ldflags = [
		"-s"
		"-w"
		"-X main.version=v${version}"
	];

	doCheck = false;

	meta = with lib; {
		description = "Autonomous AI coding agent CLI";
		homepage = "https://github.com/mlhher/late-cli";
		license = licenses.gpl2Plus;
		mainProgram = "late";
		platforms = platforms.unix;
	};
}
