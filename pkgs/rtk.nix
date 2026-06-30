{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  gnutar,
  gzip,
}: let
  version = "0.43.0";

  platformMap = {
    "aarch64-darwin" = "aarch64-apple-darwin";
    "x86_64-darwin" = "x86_64-apple-darwin";
    "aarch64-linux" = "aarch64-unknown-linux-gnu";
    "x86_64-linux" = "x86_64-unknown-linux-musl";
  };

  platform =
    platformMap.${stdenv.hostPlatform.system}
    or (throw "rtk is not supported on ${stdenv.hostPlatform.system}. Supported: aarch64-darwin, x86_64-darwin, aarch64-linux, x86_64-linux");

  nativeHashes = {
    "aarch64-apple-darwin" = "0rbcay749izlxms1r6zwnhsiy4b1z3vvc3hxn9z9jy6krfdf85wa";
    "x86_64-apple-darwin" = "1y6rqp9p7k90mdvl9pxmiis1pfn5p7cbh2326rlbw4bqcgi60px8";
    "aarch64-unknown-linux-gnu" = "0cc7k98j8754y60jc773vjl16x5rfw58mlph16k47hg52b5gf6am";
    "x86_64-unknown-linux-musl" = "02d6lbz7ig0z7n4yal9yydnzzjcpvjhyqnm8j591fvj9crvix2pz";
  };

  nativeBinary = fetchurl {
    url = "https://github.com/rtk-ai/rtk/releases/download/v${version}/rtk-${platform}.tar.gz";
    sha256 = nativeHashes.${platform};
  };
in
  stdenv.mkDerivation {
    pname = "rtk";
    inherit version;

    dontUnpack = true;
    dontStrip = true;

    nativeBuildInputs =
      [gnutar gzip]
      ++ lib.optionals stdenv.hostPlatform.isLinux [autoPatchelfHook];
    buildInputs = lib.optionals stdenv.hostPlatform.isLinux [stdenv.cc.cc.lib];

    buildPhase = ''
      runHook preBuild
      mkdir -p build
      tar -xzf ${nativeBinary} -C build
      chmod u+w,+x build/rtk
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      cp build/rtk $out/bin/rtk
      chmod +x $out/bin/rtk
      runHook postInstall
    '';

    meta = {
      description = "Rust Token Killer - compresses developer-tool output before it reaches an LLM";
      homepage = "https://github.com/rtk-ai/rtk";
      license = lib.licenses.asl20;
      platforms = ["aarch64-darwin" "x86_64-darwin" "aarch64-linux" "x86_64-linux"];
      mainProgram = "rtk";
    };
  }
