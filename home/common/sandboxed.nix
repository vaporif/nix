{
  pkgs,
  lib,
  inputs,
  ...
}: let
  inherit (pkgs.stdenv) isDarwin isLinux;
  sandnixLib = import inputs.sandnix.lib {inherit pkgs;};

  mkSandboxed = name: modules:
    sandnixLib.makeSandnix {inherit name modules;};

  # Shared secret names (read outside sandbox, injected as env vars)
  secretEnvVars = [
    {
      env = "TAVILY_API_KEY";
      file = "/run/secrets/tavily-key";
    }
    {
      env = "QDRANT_API_KEY";
      file = "/run/secrets/qdrant-api-key";
    }
    {
      env = "HF_TOKEN";
      file = "/run/secrets/hf-token-scan-injection";
    }
  ];

  # Generate pre-load script for secrets (runs before sandbox)
  secretPreload = lib.concatStringsSep "\n" (map (s: ''
      ${s.env}=""
      if [ -r ${s.file} ]; then
        ${s.env}="$(cat ${s.file})"
      fi
      export ${s.env}
    '')
    secretEnvVars);

  secretEnvNames = map (s: s.env) secretEnvVars;

  # Shared env vars to pass through the sandbox
  sharedEnvNames =
    [
      "HOME"
      "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"
      "EDITOR"
      "VISUAL"
      "ENABLE_LSP_TOOL"
      "DFT_GRAPH_LIMIT"
      "DFT_BYTE_LIMIT"
    ]
    ++ secretEnvNames;

  # macOS: sandnix with sandbox-exec (native macOS sandbox)
  darwinExtras = {
    preHook = ''
      ${secretPreload}

      cat >> "$PROFILE_FILE" <<SBPL
      ;; Scoped mach-lookup: only services needed beyond system.sb
      ;; system.sb already allows: cfprefsd, trustd, notification_center,
      ;; opendirectoryd, logd, runningboard, secinitd, etc.
      ;;
      ;; gh auth token → keychain access
      (allow mach-lookup (global-name "com.apple.SecurityServer"))
      ;; osascript display notification
      (allow mach-lookup (global-name "com.apple.usernoted"))
      ;; DNS resolution (mDNSResponder, used by getaddrinfo on macOS)
      (allow mach-lookup (global-name "com.apple.dnssd.service"))
      ;; Window server (osascript GUI interactions)
      (allow mach-lookup (global-name "com.apple.windowserver.active"))

      (allow user-preference-read)
      (allow sysctl-read)
      (allow iokit-get-properties)
      (allow system-socket)
      (allow file-read* (subpath "/Library/Preferences"))
      (allow file-read* file-write* (regex #"^$HOME/\\.claude\\.json"))
      (allow file-read* file-write* (regex #"^$HOME/\\.CFUserTextEncoding"))
      SBPL
    '';
  };

  claudeDarwin = mkSandboxed "claude" ([
      inputs.sandnix.sandnixModules.git
      inputs.sandnix.sandnixModules.gh
      {
        program = "${pkgs.claude-code}/bin/claude";
        features = {
          tty = true;
          nix = true;
          network = true;
        };
        cli = {
          rwx = ["."];
          rw = [
            "$HOME/.claude"
            "$HOME/.config/claude-rules"
            "$HOME/.cache/nix"
          ];
          env = sharedEnvNames;
        };
      }
    ]
    ++ lib.optionals isDarwin [darwinExtras]);

  # Linux: bubblewrap (user namespaces + bind mounts)
  claudeLinux = let
    bwrap = lib.getExe pkgs.bubblewrap;
    claude = "${pkgs.claude-code}/bin/claude";
  in
    pkgs.writeShellScriptBin "claude" ''
      bind_ro() { [[ -e "$1" ]] && args+=(--ro-bind "$1" "$1"); }
      bind_rw() { [[ -e "$1" ]] && args+=(--bind "$1" "$1"); }
      pass_env() { [[ -n "''${!1:-}" ]] && args+=(--setenv "$1" "''${!1}"); }

      # Pre-load secrets before sandbox (same pattern as darwin preHook)
      ${secretPreload}

      mkdir -p "$HOME/.claude" "$HOME/.cache/nix" "$HOME/.local/share/gh"

      args=(
        --unshare-all
        --share-net
        --die-with-parent
        --clearenv

        --dev /dev
        --proc /proc
        --tmpfs /tmp

        # Nix store (ro) + daemon socket (rw for connect())
        --ro-bind /nix /nix
        --bind /nix/var/nix/daemon-socket /nix/var/nix/daemon-socket

        # System config (resolv.conf, ssl certs, locale)
        --ro-bind /etc /etc
        --ro-bind /run/current-system /run/current-system

        # Home: empty tmpfs base, then selective mounts on top
        --tmpfs "$HOME"
      )

      # Working directory (after tmpfs $HOME so it's not masked)
      args+=(--bind "$(pwd)" "$(pwd)" --chdir "$(pwd)")

      # Read-write home paths
      bind_rw "$HOME/.claude"
      bind_rw "$HOME/.cache/nix"
      bind_rw "$HOME/.local/share/gh"

      # Claude config in $HOME root
      bind_rw "$HOME/.claude.json"

      # Read-only home paths
      bind_ro "$HOME/.nix-profile"
      bind_ro "$HOME/.local/state/nix"
      bind_ro "$HOME/.config/claude-rules"
      bind_ro "$HOME/.config/git"
      bind_ro "$HOME/.config/mcphub"
      bind_ro "$HOME/.config/direnv"
      bind_ro "$HOME/.ssh"
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
                 ${lib.concatStringsSep " " sharedEnvNames}; do
        pass_env "$var"
      done

      exec ${bwrap} "''${args[@]}" ${claude} "$@"
    '';

  claudeSandboxed =
    if isDarwin
    then claudeDarwin
    else claudeLinux;
in {
  config.custom.sandboxedPackages = {
    claude = claudeSandboxed;
  };
}
