{
  pkgs,
  lib,
  sandboxShared,
  ...
}: let
  bwrap = lib.getExe pkgs.bubblewrap;
  claude = "${pkgs.claude-code}/bin/claude";

  claudeLinux = pkgs.writeShellScriptBin "claude" ''
    bind_ro() { [[ -e "$1" ]] && args+=(--ro-bind "$1" "$1"); }
    bind_rw() { [[ -e "$1" ]] && args+=(--bind "$1" "$1"); }
    pass_env() { [[ -n "''${!1:-}" ]] && args+=(--setenv "$1" "''${!1}"); }

    # Pre-load secrets before sandbox
    ${sandboxShared.secretPreload}
    ${sandboxShared.ghTokenPreload}
    CLAUDE_SANDBOX=1
    export CLAUDE_SANDBOX

    mkdir -p "$HOME/.claude" "$HOME/.cache/nix" "$HOME/.cache/huggingface" "$HOME/.serena"

    args=(
      --unshare-ipc
      --unshare-pid
      --unshare-uts
      --unshare-cgroup
      --die-with-parent
      --clearenv

      --dev /dev
      --proc /proc
      --tmpfs /tmp

      # Nix store (ro) + daemon socket (rw for connect())
      --ro-bind /nix /nix
      --bind /nix/var/nix/daemon-socket /nix/var/nix/daemon-socket

      # System config (selective — avoid exposing all of /etc)
      --ro-bind /etc/resolv.conf /etc/resolv.conf
      --ro-bind /etc/ssl /etc/ssl
      --ro-bind /etc/hosts /etc/hosts
      --ro-bind /etc/passwd /etc/passwd
      --ro-bind /etc/group /etc/group
      --ro-bind /etc/nix /etc/nix
      --ro-bind /etc/static /etc/static
      --ro-bind /etc/profiles /etc/profiles
      --symlink /etc/static/claude-code /etc/claude-code
      --ro-bind /run/current-system /run/current-system

      # /bin/sh — Claude Code hook runner uses spawn('/bin/sh', ...) internally
      --symlink ${pkgs.bash}/bin/bash /bin/sh
      # /usr/bin/env — hook scripts use #!/usr/bin/env bash shebangs
      --symlink ${pkgs.coreutils}/bin/env /usr/bin/env

      # Home: empty tmpfs base, then selective mounts on top
      --tmpfs "$HOME"
    )

    # Working directory (after tmpfs $HOME so it's not masked)
    args+=(--bind "$(pwd)" "$(pwd)" --chdir "$(pwd)")

    # Read-write home paths
    bind_rw "$HOME/.claude"
    bind_rw "$HOME/.cache/nix"
    bind_rw "$HOME/.cache/huggingface"
    bind_rw "$HOME/.serena"
    bind_rw "$HOME/Repos"
    bind_ro "$HOME/.local/share/gh"

    # Claude config in $HOME root
    bind_rw "$HOME/.claude.json"

    # Read-only home paths
    bind_ro "$HOME/.nix-profile"
    bind_ro "$HOME/.local/state/nix"
    bind_ro "$HOME/.config/claude-rules"
    bind_ro "$HOME/.config/nix-darwin"
    bind_ro "$HOME/.config/git"
    bind_ro "$HOME/.config/mcphub"
    bind_ro "$HOME/.config/direnv"
    # SSH: copy config files so they're owned by current user (nix store files
    # are root-owned, which appears as nobody in the user namespace — OpenSSH rejects that)
    ssh_tmp="$(mktemp -d)"
    [[ -e "$HOME/.ssh/config" ]] && cp "$HOME/.ssh/config" "$ssh_tmp/config" && chmod 600 "$ssh_tmp/config"
    [[ -e "$HOME/.ssh/known_hosts" ]] && cp "$HOME/.ssh/known_hosts" "$ssh_tmp/known_hosts" && chmod 644 "$ssh_tmp/known_hosts"
    [[ -d "$HOME/.ssh/agent" ]] && args+=(--bind "$HOME/.ssh/agent" "$HOME/.ssh/agent")
    [[ -e "$ssh_tmp/config" ]] && args+=(--ro-bind "$ssh_tmp/config" "$HOME/.ssh/config")
    [[ -e "$ssh_tmp/known_hosts" ]] && args+=(--ro-bind "$ssh_tmp/known_hosts" "$HOME/.ssh/known_hosts")
    bind_ro "$HOME/.envrc"

    # SSH agent
    if [[ -n "''${SSH_AUTH_SOCK:-}" ]] && [[ -S "$SSH_AUTH_SOCK" ]]; then
      args+=(--bind "$SSH_AUTH_SOCK" "$SSH_AUTH_SOCK")
    fi

    # D-Bus for gh keyring (Secret Service API)
    dbus_sock="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/bus"
    if [[ -S "$dbus_sock" ]]; then
      args+=(--bind "$dbus_sock" "$dbus_sock")
      args+=(--setenv DBUS_SESSION_BUS_ADDRESS "unix:path=$dbus_sock")
    fi

    # Environment
    args+=(
      --setenv HOME "$HOME"
      --setenv USER "''${USER:-$(id -un)}"
      --setenv TERM "''${TERM:-xterm-256color}"
      --setenv PATH "''${PATH}"
      --setenv SHELL "''${SHELL:-/bin/sh}"
    )
    for var in LANG LC_ALL SSH_AUTH_SOCK \
               XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME \
               ${lib.concatStringsSep " " sandboxShared.sharedEnvNames}; do
      pass_env "$var"
    done

    exec ${bwrap} "''${args[@]}" ${claude} "$@"
  '';
in {
  config.custom.sandboxedPackages = {
    claude = claudeLinux;
  };
}
