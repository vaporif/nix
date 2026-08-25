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
  version = "0.149.1";

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
    "aarch64-apple-darwin" = "019lby9zxwpx9chd3k00i7wz7hrw4wrpzz805i6099nxqrsz8q7d";
    "x86_64-apple-darwin" = "1vw82bxnirxs0lajdp5cba7090mnnyarr6n53igdsfdpgs1pmzl5";
    "x86_64-unknown-linux-musl" = "0y32637nsrm3gwhik7kcgz7rcx0kx5b0yqpvgbb404fpqy2bfkz2";
    "aarch64-unknown-linux-musl" = "1c555mz8yfry1xpyddjph364n9fqa46vji78jklnv5cswc16ipql";
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
