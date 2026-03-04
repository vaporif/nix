{
  rustPlatform,
  difftastic-src,
}:
rustPlatform.buildRustPackage {
  pname = "difftastic";
  version = "unstable";
  src = difftastic-src;
  cargoLock.lockFile = "${difftastic-src}/Cargo.lock";
}
