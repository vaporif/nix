{
  config,
  lib,
  ...
}: let
  claudeCfg = config.custom.claude;
  llm = config.custom.llm;
  ruleFiles =
    lib.mapAttrs' (name: entry: {
      name = ".config/claude-rules/${name}.md";
      value.source = entry.source;
    })
    llm.rules;
in {
  config = lib.mkIf claudeCfg.enable {
    home.file =
      ruleFiles
      // {
        # Direnv custom function for claude rules
        ".config/direnv/lib/claude-rules.sh".source = ../../../config/direnv/claude-rules.sh;

        ".claude/CLAUDE.md".source = ../../../assistants/claude/CLAUDE.md;
      };
  };
}
