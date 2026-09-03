{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  gnutar,
  gzip,
  openssl,
  libcap,
  libz,
  bubblewrap,
  binName ? "codex",
}: let
  version = "0.153.0";

  platformMap = {
    "aarch64-darwin" = "aarch64-apple-darwin";
    "x86_64-darwin" = "x86_64-apple-darwin";
    "x86_64-linux" = "x86_64-unknown-linux-musl";
    "aarch64-linux" = "aarch64-unknown-linux-musl";
  };

  platform =
    platformMap.${stdenv.hostPlatform.system}
    or (throw "codex is not supported on ${stdenv.hostPlatform.system}. Supported: aarch64-darwin, x86_64-darwin, x86_64-linux, aarch64-linux");

  nativeHashes = {
    "aarch64-apple-darwin" = "1q9jrc4v8im6yqg98s0bhiz9f5wm3vchy0bknc7g48xyiq5wvplc";
    "x86_64-apple-darwin" = "1p4ayssh54s7ld4rzg8511mmbm9gz4wmfj5lz7jvw7ncsz3hk0v6";
    "x86_64-unknown-linux-musl" = "03k8hsgy6s6ajm58vc7fi9w0b7d61g3lmf1ckkh9v5c37lajra1m";
    "aarch64-unknown-linux-musl" = "0lrajm5723lvz2ygarx81j83ca4jbg73radvcf0w2ladblv0qb6c";
  };

  nativeBinary = fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-${platform}.tar.gz";
    sha256 = nativeHashes.${platform};
  };

  linuxRuntimePath = lib.makeBinPath (lib.optionals stdenv.hostPlatform.isLinux [bubblewrap]);
in
  stdenv.mkDerivation {
    pname = "codex";
    inherit version;

    dontUnpack = true;
    dontPatchELF = true;
    dontStrip = true;

    nativeBuildInputs = [gnutar gzip makeWrapper];
    buildInputs = lib.optionals stdenv.hostPlatform.isLinux [openssl libcap libz];

    buildPhase = ''
      runHook preBuild
      mkdir -p build
      tar -xzf ${nativeBinary} -C build
      mv build/codex-${platform} build/codex
      chmod u+w,+x build/codex
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin

      cp build/codex $out/bin/codex-raw
      chmod +x $out/bin/codex-raw
      makeWrapper "$out/bin/codex-raw" "$out/bin/${binName}" \
        --run 'export CODEX_EXECUTABLE_PATH="$HOME/.local/bin/${binName}"' \
        --set DISABLE_AUTOUPDATER 1 \
        ${lib.optionalString stdenv.hostPlatform.isLinux ''--prefix PATH : "${linuxRuntimePath}"''}
      runHook postInstall
    '';

    meta = {
      description = "OpenAI Codex CLI - AI coding assistant in your terminal";
      homepage = "https://github.com/openai/codex";
      license = lib.licenses.asl20;
      platforms = ["aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux"];
      mainProgram = binName;
    };
  }
