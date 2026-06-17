{...}: {
  imports = [./sandboxed.nix];

  # Shell-only VMs have no GUI, so skip dconf entirely. Stylix enables GTK
  # theming (which writes dconf settings) by default; home-manager's
  # `dconf load` activation then fails against the headless session bus with
  # "ca.desrt.dconf not activatable". Disabling dconf drops that step — the
  # theming has no effect without a desktop anyway.
  dconf.enable = false;

  # Qdrant runs on macOS host, NixOS connects over UTM network
}
