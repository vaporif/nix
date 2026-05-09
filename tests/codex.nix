{
  pkgs,
  home-manager,
  inputs,
  ...
}: let
  inherit (pkgs) lib;
  testSystem =
    if pkgs.stdenv.isDarwin
    then "aarch64-darwin"
    else "aarch64-linux";
  codexSandboxed = pkgs.writeShellScriptBin "codex" "";

  hm = home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    extraSpecialArgs = {inherit inputs;};
    modules = [
      ../modules/options.nix
      ../home/common/llm
      ../home/common/mcp.nix
      ../home/common/codex
      ../home/common/shell.nix
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
          secrets.tavily-key = toString (pkgs.writeText "tavily-key" "test-tavily-key");
          sandboxedPackages.codex = codexSandboxed;
        };
      }
    ];
  };

  codexConfig = hm.config.home.file.".codex/config.toml".source;
  conciseSkill = hm.config.home.file.".codex/skills/concise/SKILL.md".source;
  rustAgent = hm.config.home.file.".codex/agents/rust-engineer.md".source;
  codexBin = lib.getExe codexSandboxed;
in
  assert hm.config.programs.zsh.shellAliases.o == "${codexBin} --dangerously-bypass-approvals-and-sandbox";
  assert hm.config.programs.zsh.shellAliases."or" == "${codexBin} resume --dangerously-bypass-approvals-and-sandbox";
  assert hm.config.programs.zsh.shellAliases.ox == "${codexBin} exec";
    pkgs.runCommand "codex-config" {} ''
      grep -q '^\[mcp_servers.context7\]$' ${codexConfig}
      grep -q '^\[mcp_servers.serena\]$' ${codexConfig}
      grep -q '^\[mcp_servers.github\]$' ${codexConfig}
      grep -q '^\[mcp_servers.nixos\]$' ${codexConfig}
      grep -q '^\[mcp_servers.ferrex\]$' ${codexConfig}
      grep -q '^\[mcp_servers.tavily\]$' ${codexConfig}
      grep -q '^env_vars = \["TAVILY_API_KEY"\]$' ${codexConfig}
      grep -q '^\[projects."/home/testuser/.config/nix-darwin"\]$' ${codexConfig}
      ${lib.optionalString pkgs.stdenv.isDarwin ''
        grep -q '^\[\[hooks.PreToolUse\]\]$' ${codexConfig}
        grep -q '^matcher = "Bash|Read|Write|Edit|Glob|Grep|WebFetch|WebSearch|apply_patch|mcp__\.\*"$' ${codexConfig}
        grep -q '^\[\[hooks.PostToolUse\]\]$' ${codexConfig}
        grep -q '^\[\[hooks.UserPromptSubmit\]\]$' ${codexConfig}
        grep -q '^command = "parry-guard hook"$' ${codexConfig}
      ''}
      grep -q '^\[tui\]$' ${codexConfig}
      grep -q '^status_line = \[$' ${codexConfig}
      grep -q '^    "model-with-reasoning",$' ${codexConfig}
      grep -q '^    "context-used",$' ${codexConfig}
      grep -q '^    "branch-changes",$' ${codexConfig}
      ! grep -q '^    "permissions",$' ${codexConfig}
      ! grep -q '^    "approval-mode",$' ${codexConfig}

      test -f ${conciseSkill}
      test -f ${rustAgent}

      touch $out
    ''
