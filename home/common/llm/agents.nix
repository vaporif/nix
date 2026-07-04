{
  inputs,
  pkgs,
  ...
}: let
  bevyEngineerAgent = pkgs.runCommand "bevy-engineer.md" {} ''
    cat ${../../../llm/shared/agents/bevy-engineer.md} > $out
    {
      printf '\n\n---\n\n'
      printf '## Appendix: Bevy 0.18 migration case study (source)\n\n'
      printf 'Pinned via the `bevy-migration-gist` flake input. Update with `nix flake update bevy-migration-gist`.\n\n'
      cat ${inputs.bevy-migration-gist}/gistfile1.txt
    } >> $out
  '';
in {
  custom.llm.agents = {
    rust-engineer.source = ../../../llm/shared/agents/rust-engineer.md;
    bevy-engineer.source = bevyEngineerAgent;
    solana-developer.source = ../../../llm/shared/agents/solana-developer.md;
    unity-csharp-engineer.source = ../../../llm/shared/agents/unity-csharp-engineer.md;
  };
}
