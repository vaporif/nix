{
  rustPlatform,
  difftastic-src,
}:
rustPlatform.buildRustPackage {
  pname = "difftastic";
  version = "unstable";
  src = difftastic-src;
  cargoLock.lockFile = "${difftastic-src}/Cargo.lock";
  # Upstream master's Clojure config lists C node names (enumerator_list, initializer_list)
  # in ignore_trailing_tokens; drop once fixed upstream.
  checkFlags = ["--skip=parse::tree_sitter_parser::tests::test_tree_sitter_node_names_exist"];
}
