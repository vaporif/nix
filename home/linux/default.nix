{pkgs, ...}: {
  imports = [./sandboxed.nix];

  home.sessionVariables = {
    BINDGEN_EXTRA_CLANG_ARGS = "-I${pkgs.glibc.dev}/include";
  };

  # Qdrant runs on macOS host, NixOS connects over UTM network
}
