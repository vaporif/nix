{
  config,
  lib,
  pkgs,
  ...
}: let
  homeDir = config.home.homeDirectory;
  inherit (pkgs.stdenv) isDarwin;

  sec = config.programs.claude-code.security.settingsFragment;

  parryHook = {
    hooks = [
      {
        command = "parry-guard hook";
        type = "command";
      }
    ];
  };
in {
  home.file = {
    ".claude/settings.json".text = builtins.toJSON {
      "$schema" = "https://json.schemastore.org/claude-code-settings.json";
      alwaysThinkingEnabled = true;
      teammateMode = "tmux";
      enabledPlugins = config.custom.claude.enabledPlugins;
      statusLine = {
        type = "command";
        command = "${homeDir}/.claude/hooks/statusline.sh";
      };
      env = {
        CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
      };
      hooks = {
        PreToolUse =
          sec.hooks.PreToolUse
          ++ lib.optionals isDarwin [
            (parryHook // {matcher = "Bash|Read|Write|Edit|Glob|Grep|WebFetch|WebSearch|NotebookEdit|Task|mcp__.*";})
          ];
        PostToolUse =
          [
            {
              hooks = [
                {
                  command = "claude-formatter";
                  type = "command";
                }
              ];
              matcher = "Edit|Write";
            }
          ]
          ++ lib.optionals isDarwin [
            (parryHook // {matcher = "Read|WebFetch|Bash|mcp__github__get_file_contents|mcp__filesystem__read_file|mcp__filesystem__read_text_file";})
          ];
        inherit (sec.hooks) Notification;
        UserPromptSubmit = lib.optionals isDarwin [
          (parryHook // {matcher = "";})
        ];
      };
      permissions = {
        inherit (sec.permissions) allow deny;
      };
    };
    ".claude/settings.local.json".text = builtins.toJSON {
      permissions = {
        allow = [];
        deny = [];
      };
    };
    ".claude/hooks/statusline.sh" = {
      source = ../../../scripts/statusline.sh;
      executable = true;
    };
  };
}
