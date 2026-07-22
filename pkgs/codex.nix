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
  version = "0.144.6";

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
    "aarch64-apple-darwin" = "1mx3f4pkl09fzjj1qgmsnlzx7ifkfigf6bhkc6n0g5dw53w90d82";
    "x86_64-apple-darwin" = "0isrmij6i3yyhy4d4dr5sb6awp3pw5zfsmnj5xn4yjm2dfjq2g3n";
    "x86_64-unknown-linux-musl" = "1im1a62722hy38plkzjwpkik77y86gq3psyqhikfm35dl18yz7ba";
    "aarch64-unknown-linux-musl" = "1ghivygwvc8dhv38r94krhf4rzyrppivzq8slndzz780digaxpcf";
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
