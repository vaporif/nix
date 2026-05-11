{
  pkgs,
  config,
  inputs,
  lib,
  ...
}: let
  cfg = config.custom;
  toml = pkgs.formats.toml {};
  parryGuard = inputs.parry-guard.packages.${pkgs.stdenv.hostPlatform.system}.default;
  parryHook = {
    hooks = [
      {
        command = "${lib.getExe parryGuard} hook";
        type = "command";
      }
    ];
  };
in {
  imports = [
    ../../modules/nix.nix
    ../../modules/theme.nix
    ./preferences.nix
    ./services.nix
    ./activation.nix
    ./security.nix
    ./homebrew.nix
  ];

  time.timeZone = cfg.timezone;

  users.users.${cfg.user}.home = cfg.homeDir;

  environment.systemPackages = [
    pkgs.age
    pkgs.libressl
  ];

  environment.etc."codex/config.toml" = lib.mkIf cfg.codex.enable {
    source = toml.generate "codex-system-config.toml" {
      hooks = {
        PreToolUse = [
          (parryHook // {matcher = "Bash|Read|Write|Edit|Glob|Grep|WebFetch|WebSearch|apply_patch|mcp__.*";})
        ];
        PostToolUse = [
          (parryHook // {matcher = "Bash|Read|WebFetch|Edit|apply_patch|mcp__github__get_file_contents|mcp__filesystem__read_file|mcp__filesystem__read_text_file";})
        ];
        UserPromptSubmit = [
          (parryHook // {matcher = "";})
        ];
      };
    };
  };

  nix.enable = false;

  launchd.daemons.maxfiles = {
    command = "/bin/launchctl limit maxfiles 65536 524288";
    serviceConfig = {
      Label = "limit.maxfiles";
      RunAtLoad = true;
    };
  };

  system = {
    configurationRevision = null;
    stateVersion = 6;
    primaryUser = cfg.user;
  };

  nixpkgs.hostPlatform = cfg.system;
}
