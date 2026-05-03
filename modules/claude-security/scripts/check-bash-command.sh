# Hook contract: stdin is JSON with .tool_input.command. We emit a JSON
# permissionDecision on stdout AND exit non-zero (2) for deny, so the harness
# treats us as fail-closed even if JSON parsing breaks downstream.

deny() {
  jq -nc --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 2
}

ask() {
  jq -nc --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "ask",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

allow() { exit 0; }

input=$(cat)

# If we cannot parse the input, ask. Never silently allow.
COMMAND=$(jq -r '.tool_input.command // empty' <<<"$input" 2>/dev/null) \
  || ask "could not parse hook input"

[ -z "$COMMAND" ] && allow

BLOCKED_CMDS_JSON='@blockedCommandsJson@'
BLOCKED_SUBCMDS_JSON='@blockedSubcommandsJson@'
DENIED_SUBCMDS_JSON='@deniedSubcommandsJson@'
BLOCKED_PATTERNS_JSON='@blockedPatternsJson@'

# Walk the AST. For each CallExpr, extract a list of "command tokens".
# A token is a string ONLY when every Part is type Lit AND the joined
# literal value matches the raw source span exactly. If any Part is
# non-literal (DblQuoted, SglQuoted, ParamExp, CmdSubst, escapes that
# shfmt collapses, etc) we mark the whole token as opaque (null).
# Opaque tokens force ask().
AST=$(shfmt --to-json <<<"$COMMAND" 2>/dev/null) \
  || ask "could not parse command via shfmt"

# Extract command-prefix tokens per CallExpr.
# Output format: one JSON array per CallExpr, each element is either a
# string (concatenated Lit Parts and matching raw source) or null (opaque).
CMDS=$(jq -c --arg src "$COMMAND" '
  def tokens: [.Parts[] |
    if .Type == "Lit" then .Value
    else null end];
  def rawSpan: $src[.Pos.Offset:.End.Offset];
  [.. | objects | select(.Type == "CallExpr") |
    [.Args[]? |
      . as $arg |
      tokens as $toks |
      ($toks | add // "") as $joined |
      if any($toks[]; . == null) then null
      elif $joined != ($arg | rawSpan) then null
      elif ($joined | test("\\\\")) then null
      else $joined end]
  ]
' <<<"$AST")

# If any CallExpr has any opaque (null) token, ask the user.
if echo "$CMDS" | jq -e 'flatten | any(. == null)' >/dev/null; then
  ask "command contains non-literal tokens (variable, substitution, or quoted) — review manually"
fi

# Iterate command-prefixes (the first token of each CallExpr) for blockedCommands.
while IFS= read -r cmd; do
  [ -z "$cmd" ] && continue
  base=$(basename -- "$cmd")
  if echo "$BLOCKED_CMDS_JSON" | jq -e --arg b "$base" 'any(. == $b)' >/dev/null; then
    ask "$base detected. Confirm with user before proceeding."
  fi
done < <(echo "$CMDS" | jq -r '.[][0] // empty')

# Subcommand prefix matching. We tokenize the full prefix (e.g. ["git" "push" "--force"])
# and check against each rule's space-split tokens. A rule "git push" matches any
# command-prefix whose first N tokens equal the rule's tokens, with N = rule's
# token count. This naturally handles whitespace variations and refuses to be
# fooled by environment-variable prefixes (those are not CallExpr Args).
match_subcmd() {
  local rule_json=$1 prefix_json=$2
  jq -e --argjson rule "$rule_json" --argjson prefix "$prefix_json" '
    ($rule | length) as $n |
    ($prefix | length) >= $n and
    ($prefix[:$n]) == $rule
  ' <<<'null' >/dev/null
}

while IFS= read -r prefix_json; do
  [ -z "$prefix_json" ] || [ "$prefix_json" = "null" ] && continue
  while IFS= read -r rule; do
    [ -z "$rule" ] && continue
    rule_json=$(jq -c --arg r "$rule" '$r | split(" ")' <<<'null')
    if match_subcmd "$rule_json" "$prefix_json"; then
      deny "Command '$rule' is denied."
    fi
  done < <(echo "$DENIED_SUBCMDS_JSON" | jq -r '.[]')
  while IFS= read -r rule; do
    [ -z "$rule" ] && continue
    rule_json=$(jq -c --arg r "$rule" '$r | split(" ")' <<<'null')
    if match_subcmd "$rule_json" "$prefix_json"; then
      ask "Command '$rule' requires confirmation."
    fi
  done < <(echo "$BLOCKED_SUBCMDS_JSON" | jq -r '.[]')
done < <(echo "$CMDS" | jq -c '.[]')

# Pattern matching: blockedPatterns is a list of "src|sink" strings.
# We DENY if any CallExpr names src AND any later CallExpr in the same
# pipeline/sequence names sink. This is structural — it catches
# `curl x | sh`, `curl x; sh /tmp/x`, `curl x > /tmp/x && sh /tmp/x`.
ALL_BASES=$(echo "$CMDS" | jq -r '.[][0] // empty | split("/") | last')
while IFS= read -r pattern; do
  [ -z "$pattern" ] && continue
  src=${pattern%%|*}
  sink=${pattern##*|}
  if grep -qFx "$src" <<<"$ALL_BASES" && grep -qFx "$sink" <<<"$ALL_BASES"; then
    deny "Pattern '$pattern' detected (source and sink both present in command sequence)."
  fi
done < <(echo "$BLOCKED_PATTERNS_JSON" | jq -r '.[]')

allow
