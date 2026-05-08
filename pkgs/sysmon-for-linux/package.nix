{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, binutils
, gnutar
, xz
, zstd
, elfutils
, zlib
, json-glib
, glib
, stdenvNoCC
}:

stdenvNoCC.mkDerivation rec {
  pname = "sysmon";
  version = "1.5.2";
  versionShort = "1.5.2";
  ebpfVersion = "1.5.0";

  sysmonDeb = fetchurl {
    url = "https://github.com/microsoft/SysmonForLinux/releases/download/${version}/sysmonforlinux_${versionShort}_amd64.deb";
    sha256 = "sha256-XeIArbbMOgO3cjlPABkRmBcEjbbHu9I11vd25FnEz58=";
  };

  ebpfDeb = fetchurl {
    url = "https://github.com/microsoft/SysinternalsEBPF/releases/download/1.5.0.0/sysinternalsebpf_${ebpfVersion}_amd64.deb";
    sha256 = "sha256-33amjcDZDwkBqexSoHs/bg50Es8WhR7fitHdz/EtlP0=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    binutils
    gnutar
    xz
    zstd
  ];

  buildInputs = [
    elfutils
    zlib
    json-glib
    glib
    stdenv.cc.cc.lib
  ];

  dontConfigure = true;
  dontBuild = true;

  unpackPhase = ''
    runHook preUnpack

    mkdir -p unpack/sysmon unpack/ebpf

    cd unpack/sysmon

    ar x "$sysmonDeb"

    dataTar=""
    if [ -f data.tar.xz ]; then
      dataTar="data.tar.xz"
    elif [ -f data.tar.gz ]; then
      dataTar="data.tar.gz"
    elif [ -f data.tar.zst ]; then
      dataTar="data.tar.zst"
    elif [ -f data.tar ]; then
      dataTar="data.tar"
    else
      echo "Could not find data.tar archive inside sysmon deb"
      exit 1
    fi

    case "$dataTar" in
      *.tar.xz)
        tar -xJf "$dataTar"
        ;;
      *.tar.gz)
        tar -xzf "$dataTar"
        ;;
      *.tar.zst)
        tar --use-compress-program=unzstd -xf "$dataTar"
        ;;
      *.tar)
        tar -xf "$dataTar"
        ;;
      *)
        echo "Unsupported data archive format: $dataTar"
        exit 1
        ;;
    esac

    cd ../ebpf

    ar x "$ebpfDeb"

    dataTar=""
    if [ -f data.tar.xz ]; then
      dataTar="data.tar.xz"
    elif [ -f data.tar.gz ]; then
      dataTar="data.tar.gz"
    elif [ -f data.tar.zst ]; then
      dataTar="data.tar.zst"
    elif [ -f data.tar ]; then
      dataTar="data.tar"
    else
      echo "Could not find data.tar archive inside ebpf deb"
      exit 1
    fi

    case "$dataTar" in
      *.tar.xz)
        tar -xJf "$dataTar"
        ;;
      *.tar.gz)
        tar -xzf "$dataTar"
        ;;
      *.tar.zst)
        tar --use-compress-program=unzstd -xf "$dataTar"
        ;;
      *.tar)
        tar -xf "$dataTar"
        ;;
      *)
        echo "Unsupported data archive format: $dataTar"
        exit 1
        ;;
    esac

    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin"
    mkdir -p "$out/lib"
    mkdir -p "$out/share/sysmon"
    mkdir -p "$out/share/man/man8"

    cp "$PWD/../sysmon/usr/bin/sysmon" "$out/bin/"
    cp "$PWD/../sysmon/usr/share/man/man8/sysmon.8.gz" "$out/share/man/man8/"

    # NixOS keeps /etc/systemd/system read-only; avoid installer writes there.
    # Patch the binary string in-place with same-length replacement.
    off=$(grep -abo '/etc/systemd/system' "$out/bin/sysmon" | head -n1 | cut -d: -f1)
    if [ -z "$off" ]; then
      echo "Could not find /etc/systemd/system string in sysmon binary"
      exit 1
    fi
    printf '/opt/sysmon/disable' | dd of="$out/bin/sysmon" bs=1 seek="$off" conv=notrunc status=none

    extractBlob() {
      src="$1"
      symBase="$2"
      dst="$3"

      startHex=$(readelf -Ws "$src" | awk -v s="''${symBase}_start" '$8==s{print $2; exit}')
      endHex=$(readelf -Ws "$src" | awk -v s="''${symBase}_end" '$8==s{print $2; exit}')
      secIdx=$(readelf -Ws "$src" | awk -v s="''${symBase}_start" '$8==s{gsub(/\[|\]/, "", $7); print $7; exit}')

      if [ -z "$startHex" ] || [ -z "$endHex" ] || [ -z "$secIdx" ]; then
        echo "Failed to find embedded symbol: ''${symBase} in $src"
        exit 1
      fi

      secLine=$(readelf -W -S "$src" | awk -v idx="$secIdx" '$1=="["idx"]"{print; exit}')
      secAddr=$(echo "$secLine" | awk '{print $4}')
      secOff=$(echo "$secLine" | awk '{print $5}')

      start=$((16#$startHex))
      end=$((16#$endHex))
      addr=$((16#$secAddr))
      off=$((16#$secOff))
      fileOff=$((start - addr + off))
      size=$((end - start))

      dd if="$src" of="$dst" bs=1 skip="$fileOff" count="$size" status=none
    }

    installer="$PWD/usr/bin/libsysinternalsEBPFinstaller"
    sysmonBin="$PWD/../sysmon/usr/bin/sysmon"

    # Extract embedded libsysinternalsEBPF.so from SysinternalsEBPF installer.
    extractBlob "$installer" "_binary_libsysinternalsEBPF_so" "$out/lib/libsysinternalsEBPF.so"
    extractBlob "$installer" "_binary_sysinternalsEBPFmemDump_o" "$out/share/sysmon/sysinternalsEBPFmemDump.o"
    extractBlob "$installer" "_binary_sysinternalsEBPFrawSock_o" "$out/share/sysmon/sysinternalsEBPFrawSock.o"
    extractBlob "$installer" "_binary_offsets_offsets_json" "$out/share/sysmon/offsets.json"

    # Extract embedded eBPF objects from sysmon binary for NixOS service preStart.
    extractBlob "$sysmonBin" "_binary_sysmonEBPFkern4_15_o" "$out/share/sysmon/sysmonEBPFkern4.15.o"
    extractBlob "$sysmonBin" "_binary_sysmonEBPFkern4_16_o" "$out/share/sysmon/sysmonEBPFkern4.16.o"
    extractBlob "$sysmonBin" "_binary_sysmonEBPFkern4_17_5_1_o" "$out/share/sysmon/sysmonEBPFkern4.17-5.1.o"
    extractBlob "$sysmonBin" "_binary_sysmonEBPFkern5_2_o" "$out/share/sysmon/sysmonEBPFkern5.2.o"
    extractBlob "$sysmonBin" "_binary_sysmonEBPFkern5_3_5_5_o" "$out/share/sysmon/sysmonEBPFkern5.3-5.5.o"
    extractBlob "$sysmonBin" "_binary_sysmonEBPFkern5_6__o" "$out/share/sysmon/sysmonEBPFkern5.6-.o"
    extractBlob "$sysmonBin" "_binary_sysmonEBPFkern4_15_core_o" "$out/share/sysmon/sysmonEBPFkern4.15_core.o"
    extractBlob "$sysmonBin" "_binary_sysmonEBPFkern4_16_core_o" "$out/share/sysmon/sysmonEBPFkern4.16_core.o"
    extractBlob "$sysmonBin" "_binary_sysmonEBPFkern4_17_5_1_core_o" "$out/share/sysmon/sysmonEBPFkern4.17-5.1_core.o"
    extractBlob "$sysmonBin" "_binary_sysmonEBPFkern5_2_core_o" "$out/share/sysmon/sysmonEBPFkern5.2_core.o"
    extractBlob "$sysmonBin" "_binary_sysmonEBPFkern5_3_5_5_core_o" "$out/share/sysmon/sysmonEBPFkern5.3-5.5_core.o"
    extractBlob "$sysmonBin" "_binary_sysmonEBPFkern5_6__core_o" "$out/share/sysmon/sysmonEBPFkern5.6-_core.o"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Sysmon for Linux packaged from upstream Debian package";
    homepage = "https://github.com/microsoft/SysmonForLinux";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "sysmon";
  };
}