{
  config,
  lib,
  ...
}: let
  cfg = config.custom;
  toFile = subdir: name: entry: {
    name = ".claude/${subdir}/${name}.md";
    value.source = entry.source;
  };
in {
  config = lib.mkIf cfg.claude.enable {
    home.file =
      lib.mapAttrs' (toFile "agents") cfg.llm.agents
      // lib.mapAttrs' (toFile "commands") cfg.llm.commands;
  };
}
