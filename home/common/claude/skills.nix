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
      lib.mapAttrs' (name: entry: {
        name =
          if entry.kind == "directory"
          then ".claude/skills/${name}"
          else ".claude/skills/${name}/SKILL.md";
        value.source = entry.source;
      })
      llm.skills;
  };
}
