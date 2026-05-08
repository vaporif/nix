{
  pkgs,
  home-manager,
  inputs,
  ...
}: let
  testSystem =
    if pkgs.stdenv.isDarwin
    then "aarch64-darwin"
    else "aarch64-linux";

  hm = home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    extraSpecialArgs = {inherit inputs;};
    modules = [
      ../modules/options.nix
      ../home/common/llm
      ../home/common/mcp.nix
      ../home/common/codex
      {
        home = {
          username = "testuser";
          homeDirectory = "/home/testuser";
          stateVersion = "24.05";
        };

        custom = {
          user = "testuser";
          system = testSystem;
          configPath = "/home/testuser/.config/nix-darwin";
          codex.enable = true;
        };
      }
    ];
  };

  codexConfig = hm.config.home.file.".codex/config.toml".source;
  conciseSkill = hm.config.home.file.".codex/skills/concise/SKILL.md".source;
  rustAgent = hm.config.home.file.".codex/agents/rust-engineer.md".source;
in
  pkgs.runCommand "codex-config" {} ''
    grep -q '^\[mcp_servers.context7\]$' ${codexConfig}
    grep -q '^\[mcp_servers.serena\]$' ${codexConfig}
    grep -q '^\[mcp_servers.github\]$' ${codexConfig}
    grep -q '^\[mcp_servers.nixos\]$' ${codexConfig}
    grep -q '^\[mcp_servers.ferrex\]$' ${codexConfig}
    grep -q '^\[projects."/home/testuser/.config/nix-darwin"\]$' ${codexConfig}

    test -f ${conciseSkill}
    test -f ${rustAgent}

    touch $out
  ''
