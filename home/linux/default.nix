{...}: {
  imports = [./sandboxed.nix];

  gtk.gtk4.theme = null;

  # Qdrant runs on macOS host, NixOS connects over UTM network
}
