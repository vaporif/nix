{
  config,
  lib,
  ...
}: let
  cfg = config.custom;
  ruleFiles =
    lib.mapAttrs' (name: entry: {
      name = ".config/claude-rules/${name}.md";
      value.source = entry.source;
    })
    cfg.llm.rules;
in {
  config = lib.mkIf cfg.claude.enable {
    home.file =
      ruleFiles
      // {
        # Direnv custom function for claude rules
        ".config/direnv/lib/claude-rules.sh".source = ../../../config/direnv/claude-rules.sh;

        ".claude/CLAUDE.md".source = ../../../config/claude/CLAUDE.md;
      };
  };
}
