_: {
  home.file = {
    # Central rules store — not auto-loaded by Claude Code
    # Use `use claude_rules` in .envrc to symlink into project
    ".config/claude-rules/nix.md".source = ../../../config/claude-rules/nix.md;
    ".config/claude-rules/lua.md".source = ../../../config/claude-rules/lua.md;
    ".config/claude-rules/rust.md".source = ../../../config/claude-rules/rust.md;
    ".config/claude-rules/go.md".source = ../../../config/claude-rules/go.md;
    ".config/claude-rules/solidity.md".source = ../../../config/claude-rules/solidity.md;

    # Direnv custom function for claude rules
    ".config/direnv/lib/claude-rules.sh".source = ../../../config/direnv/claude-rules.sh;

    # Custom commands
    ".claude/commands/remember.md".source = ../../../config/claude-commands/remember.md;
    ".claude/commands/recall.md".source = ../../../config/claude-commands/recall.md;
    ".claude/commands/cleanup.md".source = ../../../config/claude-commands/cleanup.md;
    ".claude/commands/commit.md".source = ../../../config/claude-commands/commit.md;
    ".claude/commands/pr.md".source = ../../../config/claude-commands/pr.md;
    ".claude/commands/docs.md".source = ../../../config/claude-commands/docs.md;
    ".claude/commands/vulnix-triage.md".source = ../../../config/claude-commands/vulnix-triage.md;
    ".claude/commands/checkpoint.md".source = ../../../config/claude-commands/checkpoint.md;

    # Standalone agents
    ".claude/agents/refactoring-specialist.md".source = ../../../config/claude-agents/refactoring-specialist.md;
    ".claude/agents/performance-engineer.md".source = ../../../config/claude-agents/performance-engineer.md;
    ".claude/agents/mcp-developer.md".source = ../../../config/claude-agents/mcp-developer.md;
    ".claude/agents/cli-developer.md".source = ../../../config/claude-agents/cli-developer.md;
    ".claude/agents/rust-engineer.md".source = ../../../config/claude-agents/rust-engineer.md;
    ".claude/agents/solana-developer.md".source = ../../../config/claude-agents/solana-developer.md;

    ".claude/CLAUDE.md".source = ../../../config/claude/CLAUDE.md;
  };
}
