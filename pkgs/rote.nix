{
  lib,
  stdenv,
  fetchurl,
  gnutar,
  gzip,
  makeWrapper,
  nodejs,
  deno,
}: let
  version = "0.16.0";

  platformMap = {
    "aarch64-darwin" = "rote-macos-aarch64";
    "x86_64-darwin" = "rote-macos-x86_64";
    "aarch64-linux" = "rote-linux-aarch64";
    "x86_64-linux" = "rote-linux-x86_64";
  };

  platform =
    platformMap.${stdenv.hostPlatform.system}
    or (throw "rote is not packaged for ${stdenv.hostPlatform.system}");

  hashes = {
    "rote-macos-aarch64" = "sha256-jL6wogAFrfKj4QyqnrzMo9rEZchkq9kKKjc3I6bdlNQ=";
    "rote-macos-x86_64" = "sha256-5q3qvFCrOAoMLAEPxdTGJqgW+4YRONQhZGupU4nzrr0=";
    "rote-linux-aarch64" = "sha256-xEWKmYrsHAHHLTaiL5PgB02xZILMQCaY2d3BiThdx/Q=";
    "rote-linux-x86_64" = "sha256-imxNBqYaI3SzJ7Zpu5qDfGVJu65qClNFmM7GfS4N60Q=";
  };

  src = fetchurl {
    url = "https://github.com/modiqo/rote-releases/releases/download/v${version}/${platform}.tar.gz";
    hash = hashes.${platform};
  };

  runtimePath = lib.makeBinPath [nodejs deno];
in
  stdenv.mkDerivation {
    pname = "rote";
    inherit version src;

    dontUnpack = true;
    dontPatchELF = true;
    dontStrip = true;

    nativeBuildInputs = [gnutar gzip makeWrapper];

    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin $out/libexec build
      tar -xzf $src -C build

      install -Dm755 build/rote $out/libexec/rote
      install -Dm755 build/rote-stdio-daemon $out/libexec/rote-stdio-daemon

      makeWrapper $out/libexec/rote $out/bin/rote \
        --prefix PATH : "${runtimePath}"
      makeWrapper $out/libexec/rote-stdio-daemon $out/bin/rote-stdio-daemon \
        --prefix PATH : "${runtimePath}"
      runHook postInstall
    '';

    meta = {
      description = "Rote — execution context engineering CLI";
      homepage = "https://getrote.dev";
      license = lib.licenses.unfree;
      platforms = builtins.attrNames platformMap;
      mainProgram = "rote";
      sourceProvenance = with lib.sourceTypes; [binaryNativeCode];
    };
  }
