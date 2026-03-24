{
  pkgs,
  inputs,
  sandboxShared,
  ...
}: let
  sandnixLib = import inputs.sandnix.lib {inherit pkgs;};

  mkSandboxed = name: modules:
    sandnixLib.makeSandnix {inherit name modules;};

  darwinExtras = {
    preHook = ''
      ${sandboxShared.secretPreload}
      ${sandboxShared.ghTokenPreload}
      CLAUDE_SANDBOX=1
      export CLAUDE_SANDBOX
      CARGO_NET_GIT_FETCH_WITH_CLI=true
      export CARGO_NET_GIT_FETCH_WITH_CLI

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

      (allow user-preference-read)
      (allow sysctl-read)
      (allow iokit-get-properties)
      (allow system-socket)
      (allow file-read* (subpath "/Library/Preferences"))
      (allow file-read* file-write* (regex #"^$HOME/\\.claude\\.json"))
      (allow file-read* file-write* (regex #"^$HOME/\\.CFUserTextEncoding"))

      ;; Plugin hooks need process-exec (shebang → /usr/bin/env)
      (allow process-exec (subpath "$HOME/.claude/plugins/cache"))
      SBPL
    '';
  };

  claudeDarwin = mkSandboxed "claude" [
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
        rwx = ["." "$HOME/.claude" "$HOME/Repos"];
        rw = [
          "$HOME/.cache/nix"
          "$HOME/.cache/huggingface"
          "$HOME/.cache/gh"
          "$HOME/.cargo"
          "$HOME/.serena"
        ];
        ro = [
          "$HOME/.config/claude-rules"
          "$HOME/.config/nix-darwin"
          "$HOME/.ssh/known_hosts"
          "$HOME/.ssh/config"
        ];
        env = sandboxShared.sharedEnvNames;
      };
    }
    darwinExtras
  ];
in {
  config.custom.sandboxedPackages = {
    claude = claudeDarwin;
  };
}
