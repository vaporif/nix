#!/usr/bin/env bash
# PreToolUse hook for Bash commands
# Uses shfmt to parse command AST and extract actual executables,
# then checks against a blocklist. This catches dangerous commands
# hidden inside pipes, subshells, or command substitution that
# the Claude Code permission system can't see.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [[ -z "$COMMAND" ]]; then
  exit 0
fi

block() {
  jq -n --arg reason "$1" '{ hookSpecificOutput: { hookEventName: "PreToolUse", permissionDecision: "ask", permissionDecisionReason: $reason } }'
  exit 0
}

deny() {
  jq -n --arg reason "$1" '{ hookSpecificOutput: { hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason } }'
  exit 0
}

# Extract all command names from the bash AST using shfmt
COMMANDS=$(shfmt --to-json <<< "$COMMAND" 2>/dev/null | jq -r '
  [
    (.. | objects | select(.Type == "CallExpr") | .Args[0]?.Parts[0]?.Value // empty),
    (.. | objects | select(.Type == "DeclClause") | .Variant.Value)
  ] | unique | .[]' 2>/dev/null)

# Fallback if shfmt fails
if [[ -z "$COMMANDS" ]]; then
  COMMANDS=$(echo "$COMMAND" | tr '|;&' '\n' | awk '{print $1}' | sort -u)
fi

# Blocklist: commands that should never run without confirmation
BLOCKED="@blockedCommands@"
for cmd in $COMMANDS; do
  cmd_base=$(basename "$cmd")
  for blocked in $BLOCKED; do
    if [[ "$cmd_base" == "$blocked" ]]; then
      block "${cmd_base} detected. Confirm with user before proceeding."
    fi
  done
done

# Check for denied subcommands (hard block, even in unrestricted mode)
DENIED_SUBCMDS="@deniedSubcommands@"
while IFS= read -r subcmd; do
  [[ -z "$subcmd" ]] && continue
  if echo "$COMMAND" | grep -qE "(^|[;&|]\s*)${subcmd}(\s|$|;|&|\|)"; then
    deny "${subcmd} is not allowed."
  fi
done <<< "$DENIED_SUBCMDS"

# Check for blocked subcommands (ask for confirmation)
BLOCKED_SUBCMDS="@blockedSubcommands@"
while IFS= read -r subcmd; do
  [[ -z "$subcmd" ]] && continue
  if echo "$COMMAND" | grep -qE "(^|[;&|]\s*)${subcmd}(\s|$|;|&|\|)"; then
    block "${subcmd} detected. Confirm with user before proceeding."
  fi
done <<< "$BLOCKED_SUBCMDS"

# Catch piping remote content to a shell/interpreter
PATTERNS="@blockedPatterns@"
for pattern in $PATTERNS; do
  if echo "$COMMAND" | grep -qE "$pattern"; then
    block "Piping remote content to shell/interpreter. Confirm with user."
  fi
done

exit 0
