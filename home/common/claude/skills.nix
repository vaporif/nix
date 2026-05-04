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
  home.file = {
    ".claude/skills/humanizer/SKILL.md".source = "${inputs.humanizer}/SKILL.md";
    ".claude/skills/napkin/SKILL.md".source = "${inputs.napkin}/SKILL.md";
    ".claude/skills/caveman/SKILL.md".source = "${inputs.caveman}/skills/caveman/SKILL.md";
    ".claude/skills/post-implementation-polish/SKILL.md".source = ../../../config/claude/skills/post-implementation-polish.md;
    ".claude/skills/improve-codebase-architecture".source = "${patchedMattpocockSkills}/skills/engineering/improve-codebase-architecture";
  };
}
