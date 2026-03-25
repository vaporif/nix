{
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
}: let
  version = "0.7.3";
in
  rustPlatform.buildRustPackage {
    pname = "unclog";
    inherit version;

    src = fetchFromGitHub {
      owner = "informalsystems";
      repo = "unclog";
      rev = "v${version}";
      hash = "sha256-UebNRzPEhMPwbzlRIvrKl5sdjbwyo6nA6fJQeqM0I6g=";
    };

    cargoHash = "sha256-sHYdDhfkxDazKQjhho3q+dN2ylbPeSeBPJai1lgDeRk=";
    nativeBuildInputs = [pkg-config];
    buildInputs = [openssl];

    # Patch to fix time crate Rust 1.80+ compatibility
    postPatch = ''
      for f in $(find $cargoDepsCopy -name "mod.rs" -path "*time-*/format_description/parse/*"); do
        substituteInPlace "$f" \
          --replace-quiet '.collect::<Result<Box<_>, _>>()' \
                          '.collect::<Result<Vec<_>, _>>().map(|v| v.into_boxed_slice())'
      done
    '';
  }
