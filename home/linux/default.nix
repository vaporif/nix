{pkgs, ...}: let
  agentLink = "$HOME/.ssh/agent/current";
in {
  imports = [
    ./autotrash.nix
    ./sandboxed.nix
  ];

  home.packages = [pkgs.ghostty.terminfo];

  # Shell-only VMs have no GUI, so skip dconf entirely. Stylix enables GTK
  # theming (which writes dconf settings) by default; home-manager's
  # `dconf load` activation then fails against the headless session bus with
  # "ca.desrt.dconf not activatable". Disabling dconf drops that step — the
  # theming has no effect without a desktop anyway.
  dconf.enable = false;

  # tmux outlives the ssh login that started it, so its shells keep a forwarded
  # agent socket that dies with that login, and ssh/git then hang at publickey
  # auth. sshd runs ~/.ssh/rc on every login: point a stable link at the live
  # socket there, and have shells inside tmux use the link.
  home.file.".ssh/rc".text = ''
    if [ -S "$SSH_AUTH_SOCK" ] && [ "$SSH_AUTH_SOCK" != "${agentLink}" ]; then
      ln -sfn "$SSH_AUTH_SOCK" "${agentLink}"
    fi
  '';
  programs.zsh.initContent = ''
    [[ -n "''${TMUX:-}" ]] && export SSH_AUTH_SOCK="${agentLink}"
  '';

  # Qdrant runs on macOS host, NixOS connects over UTM network
}
