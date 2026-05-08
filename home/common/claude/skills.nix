{
  config,
  lib,
  ...
}: let
  cfg = config.custom;
in {
  config = lib.mkIf cfg.claude.enable {
    home.file =
      lib.mapAttrs' (name: entry: {
        name =
          if entry.kind == "directory"
          then ".claude/skills/${name}"
          else ".claude/skills/${name}/SKILL.md";
        value.source = entry.source;
      })
      cfg.llm.skills;
  };
}
