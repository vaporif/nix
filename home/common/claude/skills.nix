{
  inputs,
  pkgs,
  ...
}: let
  patchedHumanizer = pkgs.applyPatches {
    name = "humanizer-patched";
    src = inputs.humanizer;
    patches = [../../../patches/humanizer-emdash-to-hyphen.patch];
  };
in {
  home.file = {
    ".claude/skills/humanizer/SKILL.md".source = "${patchedHumanizer}/SKILL.md";
    ".claude/skills/napkin/SKILL.md".source = "${inputs.napkin}/SKILL.md";
    ".claude/skills/post-implementation-polish/SKILL.md".source = ../../../config/claude/skills/post-implementation-polish.md;
  };
}
