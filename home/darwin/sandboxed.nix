{
  config,
  lib,
  pkgs,
  inputs,
  sandboxShared,
  ...
}: let
  cfg = config.custom;
  sandnixLib = import inputs.sandnix.lib {inherit pkgs;};

  mkSandboxed = name: modules:
    sandnixLib.makeSandnix {inherit name modules;};

  darwinExtras = sandboxEnv: {
    preHook = ''
      ${sandboxShared.secretPreload}
      ${sandboxShared.ghTokenPreload}
      ${sandboxEnv}=1
      export ${sandboxEnv}
      CARGO_NET_GIT_FETCH_WITH_CLI=true
      export CARGO_NET_GIT_FETCH_WITH_CLI
      LIBCLANG_PATH="${pkgs.libclang.lib}/lib"
      export LIBCLANG_PATH

      mkdir -p "$HOME/Library/Application Support/kurtosis"

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
      ;; OAuth token refresh — Node.js may use these for HTTPS credential endpoints
      (allow mach-lookup (global-name "com.apple.trustd.agent"))
      (allow mach-lookup (global-name "com.apple.nsurlsessiond"))
      ;; TLS certificate chain validation + HTTP auth broker (needed for OAuth refresh)
      (allow mach-lookup (global-name "com.apple.securityd"))
      (allow mach-lookup (global-name "com.apple.CFNetwork.AuthBrokerAgent"))
      ;; Docker/OrbStack needs SCDynamicStore for network configuration
      (allow mach-lookup (global-name "com.apple.SystemConfiguration.configd"))

      (allow user-preference-read)
      (allow sysctl-read)
      (allow iokit-get-properties)
      (allow system-socket)
      (allow file-read* (subpath "/Library/Preferences"))
      (allow file-read* file-write* (regex #"^$HOME/\\.claude\\.json"))
      (allow file-read* file-write* (regex #"^$HOME/\\.CFUserTextEncoding"))
      ;; Keychain database access (token storage/refresh)
      (allow file-read* file-write* (subpath "$HOME/Library/Keychains"))
      ;; Codex can store auth state under Application Support on macOS.
      (allow file-read* file-write* (subpath "$HOME/Library/Application Support/Codex"))
      ;; Security framework MDS shared memory
      (allow file-read* (subpath "/private/var/db/mds"))

      ;; Plugin hooks need process-exec (shebang → /usr/bin/env)
      (allow process-exec (subpath "$HOME/.claude/plugins/cache"))
      SBPL
    '';
  };

  claudeDarwin = mkSandboxed "claude" [
    inputs.sandnix.sandnixModules.git
    inputs.sandnix.sandnixModules.gh
    {
      program = lib.getExe pkgs.claude-code;
      features = {
        tty = true;
        nix = true;
        network = true;
        tmp = true;
      };
      cli = {
        rwx = ["." "$HOME/.claude" "$HOME/Repos" "$HOME/.cargo"];
        rw = [
          "$HOME/.cache/nix"
          "$HOME/.cache/huggingface"
          "$HOME/.cache/gh"
          "$HOME/.serena"
          "$HOME/.ferrex"
          "$HOME/Library/Application Support/kurtosis"
          "$HOME/.orbstack/run"
          "$HOME/Library/Caches/go-build"
          "$HOME/go/pkg/mod"
        ];
        rox = [
          "/Applications/OrbStack.app/Contents/MacOS/xbin"
        ];
        ro = [
          "$HOME/.config/claude-rules"
          "$HOME/.config/nix-darwin"
          "$HOME/.ssh/known_hosts"
          "$HOME/.ssh/config"
          "$HOME/.docker/config.json"
          "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"
        ];
        env = sandboxShared.sharedEnvNames;
      };
    }
    (darwinExtras "CLAUDE_SANDBOX")
  ];

  codexDarwin = mkSandboxed "codex" [
    inputs.sandnix.sandnixModules.git
    inputs.sandnix.sandnixModules.gh
    {
      program = lib.getExe pkgs.codex;
      features = {
        tty = true;
        nix = true;
        network = true;
        tmp = true;
      };
      cli = {
        rwx = ["." "$HOME/.codex" "$HOME/Repos" "$HOME/.cargo"];
        rw = [
          "$HOME/.cache/nix"
          "$HOME/.cache/huggingface"
          "$HOME/.cache/gh"
          "$HOME/.serena"
          "$HOME/.ferrex"
          "$HOME/Library/Application Support/Codex"
          "$HOME/Library/Caches/go-build"
          "$HOME/go/pkg/mod"
        ];
        rox = [
          "/Applications/OrbStack.app/Contents/MacOS/xbin"
        ];
        ro = [
          "$HOME/.config/nix-darwin"
          "$HOME/.ssh/known_hosts"
          "$HOME/.ssh/config"
          "$HOME/.docker/config.json"
          "/etc/codex"
          "/etc/static/codex"
          "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"
        ];
        env = sandboxShared.sharedEnvNames;
      };
    }
    (darwinExtras "CODEX_SANDBOX")
  ];
in {
  config.custom.sandboxedPackages = lib.mkMerge [
    (lib.mkIf cfg.claude.enable {
      claude = claudeDarwin;
    })
    (lib.mkIf cfg.codex.enable {
      codex = codexDarwin;
    })
  ];
}
