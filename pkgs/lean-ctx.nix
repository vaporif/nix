{
  lib,
  stdenv,
  fetchurl,
  gnutar,
  gzip,
}: let
  version = "3.6.7";

  platformMap = {
    "aarch64-darwin" = "aarch64-apple-darwin";
    "x86_64-darwin" = "x86_64-apple-darwin";
    "x86_64-linux" = "x86_64-unknown-linux-musl";
    "aarch64-linux" = "aarch64-unknown-linux-musl";
  };

  platform =
    platformMap.${stdenv.hostPlatform.system}
    or (throw "lean-ctx is not supported on ${stdenv.hostPlatform.system}. Supported: aarch64-darwin, x86_64-darwin, x86_64-linux, aarch64-linux");

  hashes = {
    "aarch64-apple-darwin" = "sha256-YMOxLeEMvqY2DQirqo8Qc1cFgGd6ewFGYveb0A/uaNw=";
    "x86_64-apple-darwin" = "sha256-uBxnREkdzf3V3tb68KJz9iXWxs5fWqCkOCJ6X6B7B5M=";
    "aarch64-unknown-linux-musl" = "sha256-1GCPa2Sr6S3Xgg04a6GazLZEwlQ/oaehkk4cEc45I5I=";
    "x86_64-unknown-linux-musl" = "sha256-9W8/GBp+HZNI7wHotSZq7hvB8Whgda3NrSK1ydySUMo=";
  };

  src = fetchurl {
    url = "https://github.com/yvgude/lean-ctx/releases/download/v${version}/lean-ctx-${platform}.tar.gz";
    hash = hashes.${platform};
  };
in
  stdenv.mkDerivation {
    pname = "lean-ctx";
    inherit version src;

    dontUnpack = true;
    dontPatchELF = true;
    dontStrip = true;

    nativeBuildInputs = [gnutar gzip];

    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      tar -xzf ${src} -C $out/bin
      chmod +x $out/bin/lean-ctx
      runHook postInstall
    '';

    meta = {
      description = "Context Runtime for AI Agents — token compression, MCP tools, cross-session memory";
      homepage = "https://github.com/yvgude/lean-ctx";
      license = lib.licenses.asl20;
      platforms = ["aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux"];
      mainProgram = "lean-ctx";
    };
  }
