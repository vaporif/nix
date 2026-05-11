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
    concise.source = ../../../assistants/shared/skills/concise.md;
    post-implementation-polish.source = ../../../assistants/shared/skills/post-implementation-polish.md;
    improve-codebase-architecture = {
      source = "${patchedMattpocockSkills}/skills/engineering/improve-codebase-architecture";
      kind = "directory";
    };
  };
}
