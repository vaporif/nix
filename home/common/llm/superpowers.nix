{
  inputs,
  lib,
  pkgs,
  ...
}: {
  options.custom.llm.superpowersPackage = lib.mkOption {
    type = lib.types.package;
    readOnly = true;
    description = "Superpowers plugin source with local patches applied. Shared by the Claude plugin and Codex skills.";
  };

  config.custom.llm.superpowersPackage = pkgs.applyPatches {
    name = "superpowers-patched";
    src = inputs.superpowers;
    patches = map (n: ../../../patches/superpowers + "/${n}") [
      "brainstorming.patch"
      "writing-plans.patch"
      "executing-plans.patch"
      "subagent-driven-development.patch"
      "requesting-code-review.patch"
    ];
  };
}
