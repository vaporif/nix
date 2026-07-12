{
  inputs,
  pkgs,
  ...
}: let
  patchedMattpocockSkills = pkgs.applyPatches {
    name = "mattpocock-skills-patched";
    src = inputs.mattpocock-skills;
    patches = [../../../patches/mattpocock-skills-customizations.patch];
  };
in {
  custom.llm.skills = {
    humanizer.source = "${inputs.humanizer}/SKILL.md";
    napkin.source = "${inputs.napkin}/SKILL.md";
    concise.source = ../../../llm/shared/skills/concise.md;
    post-implementation-polish.source = ../../../llm/shared/skills/post-implementation-polish.md;
    spec-review.source = ../../../llm/shared/skills/spec-review.md;
    improve-codebase-architecture = {
      source = "${patchedMattpocockSkills}/skills/engineering/improve-codebase-architecture";
      kind = "directory";
    };
  };
}
