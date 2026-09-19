{
  config,
  lib,
  ...
}: let
  claudeCfg = config.custom.claude;
  llm = config.custom.llm;
in {
  config = lib.mkIf claudeCfg.enable {
    home.file =
      # Agents go to a central store rather than ~/.claude/agents so they are
      # not loaded into every session. `use claude_agents` in a project's .envrc
      # symlinks the relevant ones into its .claude/agents/. See direnv-agents.sh.
      lib.mapAttrs' (name: entry: {
        name = ".config/claude-agents/${name}.md";
        value.source = entry.source;
      })
      llm.agents
      // lib.mapAttrs' (name: entry: {
        name = ".claude/commands/${name}.md";
        value.source = entry.source;
      })
      llm.commands
      // {
        ".config/direnv/lib/claude-agents.sh".source = ../direnv-agents.sh;
      };
  };
}
