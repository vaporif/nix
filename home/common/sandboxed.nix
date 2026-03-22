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

  darwinSbplHook = lib.optionalString isDarwin ''
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

  claudeSandboxed = mkSandboxed "claude" [
    inputs.sandnix.sandnixModules.git
    inputs.sandnix.sandnixModules.gh
    {
      program = "${pkgs.claude-code}/bin/claude";
      features = {
        tty = true;
        nix = true;
        network = true;
      };
      preHook = darwinSbplHook;
      cli = {
        rwx = ["."];
        rw =
          [
            "$HOME/.claude"
            "$HOME/.config/claude-rules"
            "$HOME/.cache/nix"
          ]
          ++ lib.optionals isDarwin [
            "$HOME/Library/Keychains"
          ];
        env = [
          "HOME"
          "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"
        ];
      };
    }
  ];
in {
  config.custom.sandboxedPackages = {
    claude = claudeSandboxed;
  };
}
