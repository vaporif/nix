{
  pkgs,
  lib,
  inputs,
  ...
}: let
  inherit (pkgs.stdenv) isDarwin;
  sandnixLib = import inputs.sandnix.lib {inherit pkgs;};

  mkSandboxed = name: modules:
    sandnixLib.makeSandnix {inherit name modules;};

  # sandnix on darwin uses sandbox-exec (SBPL profiles).
  # Node.js needs additional macOS IPC/socket permissions beyond
  # what sandnix provides by default.
  darwinExtras = {
    preHook = ''
      # Pre-load secrets before sandbox starts (sandbox denies /run/secrets)
      TAVILY_API_KEY=""
      QDRANT_API_KEY=""
      HF_TOKEN=""
      if [ -r /run/secrets/tavily-key ]; then
        TAVILY_API_KEY="$(cat /run/secrets/tavily-key)"
      fi
      if [ -r /run/secrets/qdrant-api-key ]; then
        QDRANT_API_KEY="$(cat /run/secrets/qdrant-api-key)"
      fi
      if [ -r /run/secrets/hf-token-scan-injection ]; then
        HF_TOKEN="$(cat /run/secrets/hf-token-scan-injection)"
      fi
      CLAUDE_SANDBOX=1
      export TAVILY_API_KEY QDRANT_API_KEY HF_TOKEN CLAUDE_SANDBOX

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

  claudeSandboxed = mkSandboxed "claude" ([
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
          rwx = ["." "$HOME/.claude"];
          rw = [
            "$HOME/.config/claude-rules"
            "$HOME/.cache/nix"
          ];
          env = [
            "HOME"
            "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"
            "TAVILY_API_KEY"
            "QDRANT_API_KEY"
            "HF_TOKEN"
            "CLAUDE_SANDBOX"
            "EDITOR"
            "VISUAL"
            "ENABLE_LSP_TOOL"
            "DFT_GRAPH_LIMIT"
            "DFT_BYTE_LIMIT"
          ];
        };
      }
    ]
    ++ lib.optionals isDarwin [darwinExtras]);
in {
  config.custom.sandboxedPackages = {
    claude = claudeSandboxed;
  };
}
