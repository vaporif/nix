{
  pkgs,
  lib,
  inputs,
  ...
}: let
  sandnixLib = import inputs.sandnix.lib {inherit pkgs;};

  mkSandboxed = name: modules:
    sandnixLib.makeSandnix {inherit name modules;};

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
  ];
in {
  config.custom.sandboxedPackages = {
    claude = claudeSandboxed;
  };
}
