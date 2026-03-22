{
  pkgs,
  lib,
  inputs,
  ...
}: let
  isDarwin = pkgs.stdenv.isDarwin;
  sandnixLib = import inputs.sandnix.lib {inherit pkgs;};

  mkSandboxed = name: modules:
    sandnixLib.makeSandnix {inherit name modules;};

  # sandnix on darwin uses sandbox-exec (SBPL profiles).
  # Node.js needs additional macOS IPC/socket permissions beyond
  # what sandnix provides by default.
  darwinExtras = {
    preHook = ''
      cat >> "$PROFILE_FILE" <<SBPL
      (allow mach-lookup)
      (allow user-preference-read)
      (allow sysctl-read)
      (allow iokit-get-properties)
      (allow system-socket)
      (allow file-read* (subpath "/Library/Preferences"))
      (allow file-read* file-write* (regex #"^$HOME/\\.claude\\.json"))
      (allow file-read* file-write* (regex #"^$HOME/\\.CFUserTextEncoding"))
      SBPL
    '';
    cli.rw = ["$HOME/Library/Keychains"];
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
          rwx = ["."];
          rw = [
            "$HOME/.claude"
            "$HOME/.config/claude-rules"
            "$HOME/.cache/nix"
          ];
          env = [
            "HOME"
            "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"
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
