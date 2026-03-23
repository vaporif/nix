{inputs, ...}: {
  home.file = {
    ".claude/skills/humanizer/SKILL.md".source = "${inputs.humanizer}/SKILL.md";
    ".claude/skills/napkin/SKILL.md".source = "${inputs.napkin}/SKILL.md";
  };
}
