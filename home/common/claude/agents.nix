{
  config,
  lib,
  ...
}: let
  claudeCfg = config.custom.claude;
  llm = config.custom.llm;
  toFile = subdir: name: entry: {
    name = ".claude/${subdir}/${name}.md";
    value.source = entry.source;
  };
in {
  config = lib.mkIf claudeCfg.enable {
    home.file =
      lib.mapAttrs' (toFile "agents") llm.agents
      // lib.mapAttrs' (toFile "commands") llm.commands;
  };
}
