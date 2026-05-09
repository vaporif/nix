{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.custom;
  inherit (cfg) llm;
  inherit (pkgs.stdenv) isDarwin;
  toml = pkgs.formats.toml {};

  parryHook = {
    hooks = [
      {
        command = "parry-guard hook";
        type = "command";
      }
    ];
  };

  codexConfig =
    {
      projects.${cfg.configPath}.trust_level = "trusted";
      tui.status_line = [
        "model-with-reasoning"
        "used-tokens"
        "context-window-size"
        "context-used"
        "five-hour-limit"
        "weekly-limit"
        "git-branch"
        "branch-changes"
      ];
      tui.model_availability_nux."gpt-5.5" = 1;
      mcp_servers = cfg.codexMcpServers;
    }
    // lib.optionalAttrs isDarwin {
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

  toSkillFile = name: entry: {
    name =
      if entry.kind == "directory"
      then ".codex/skills/${name}"
      else ".codex/skills/${name}/SKILL.md";
    value.source = entry.source;
  };

  toAgentFile = name: entry: {
    name = ".codex/agents/${name}.md";
    value.source = entry.source;
  };
in {
  config = lib.mkIf cfg.codex.enable {
    home.file =
      {
        ".codex/config.toml" = {
          source = toml.generate "codex-config.toml" codexConfig;
          force = true;
        };
      }
      // lib.mapAttrs' toSkillFile llm.skills
      // lib.mapAttrs' toAgentFile llm.agents;
  };
}
