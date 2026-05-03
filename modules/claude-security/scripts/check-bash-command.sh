# PreToolUse hook. stdin is JSON with .tool_input.command. We print the
# permissionDecision JSON on stdout and exit 2 for deny, so the harness
# fails closed if downstream JSON parsing breaks.

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

# Unparsable input → ask, never silently allow.
COMMAND=$(jq -r '.tool_input.command // empty' <<<"$input" 2>/dev/null) \
  || ask "could not parse hook input"

[ -z "$COMMAND" ] && allow

BLOCKED_CMDS_JSON='@blockedCommandsJson@'
BLOCKED_SUBCMDS_JSON='@blockedSubcommandsJson@'
DENIED_SUBCMDS_JSON='@deniedSubcommandsJson@'
BLOCKED_PATTERNS_JSON='@blockedPatternsJson@'

# Per CallExpr we want a list of arg tokens. A token is a string only when
# every Part is Lit AND the joined literal matches the raw source span
# exactly. Anything else (DblQuoted, SglQuoted, ParamExp, CmdSubst, an
# escape that shfmt collapsed) becomes null — opaque, forces ask.
AST=$(shfmt --to-json <<<"$COMMAND" 2>/dev/null) \
  || ask "could not parse command via shfmt"

# CMDS = [[token-or-null, ...], ...] — one inner array per CallExpr.
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

# Any opaque token anywhere in any CallExpr → ask. Broad on purpose: a
# non-literal arg can mask a deny rule (e.g. `git "$(echo push)" --force`
# wouldn't match the "git push" prefix because the middle token is null).
# Cost: also asks on benign quoted args like `echo "hello"`.
if echo "$CMDS" | jq -e 'flatten | any(. == null)' >/dev/null; then
  ask "command contains non-literal tokens (variable, substitution, or quoted) — review manually"
fi

# blockedCommands: match by the basename of the first token in each CallExpr.
while IFS= read -r cmd; do
  [ -z "$cmd" ] && continue
  base=$(basename -- "$cmd")
  if echo "$BLOCKED_CMDS_JSON" | jq -e --arg b "$base" 'any(. == $b)' >/dev/null; then
    ask "$base detected. Confirm with user before proceeding."
  fi
done < <(echo "$CMDS" | jq -r '.[][0] // empty')

# Subcommand prefix match. Each rule "git push" splits into tokens ["git" "push"]
# and matches a CallExpr whose first 2 args are exactly those. Whitespace in the
# input collapses cleanly; env-var prefixes don't fool us because shfmt parses
# them as Assigns, not Args.
#
# One jq pass per command: emit "deny <rule>" / "ask <rule>" for the first match
# per CallExpr. Deny lines come first so the bash loop hits them first.
MATCHES=$(jq -nr \
  --argjson cmds "$CMDS" \
  --argjson denyRules "$DENIED_SUBCMDS_JSON" \
  --argjson askRules "$BLOCKED_SUBCMDS_JSON" '
  def tokenize: split(" ");
  def matchPrefix($rules; $prefix):
    first(
      $rules[] as $r |
      ($r | tokenize) as $rt |
      select(($prefix | length) >= ($rt | length) and ($prefix[:($rt | length)]) == $rt) |
      $r
    ) // empty;
  $cmds[] |
    select(length > 0 and (any(.[]; . == null) | not)) as $prefix |
    (matchPrefix($denyRules; $prefix) | "deny " + .),
    (matchPrefix($askRules; $prefix) | "ask " + .)
')

while IFS= read -r line; do
  [ -z "$line" ] && continue
  action=${line%% *}
  rule=${line#* }
  case $action in
    deny) deny "Command '$rule' is denied." ;;
    ask) ask "Command '$rule' requires confirmation." ;;
  esac
done <<<"$MATCHES"

# blockedPatterns are "src|sink" pairs. Deny if both names appear as
# CallExpr basenames anywhere in the command. Structural, not regex —
# catches `curl x | sh`, `curl x; sh /tmp/x`, `curl x > /tmp/x && sh /tmp/x`.
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
