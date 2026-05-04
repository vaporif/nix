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
PIPE_SOURCES_JSON='@pipeSourcesJson@'
PIPE_SINKS_JSON='@pipeSinksJson@'

# Per CallExpr we want a list of arg tokens. A token is a known string when
# every Part is one of:
#   - Lit (no backslash — bash escapes are preserved by shfmt as raw `\`,
#     so the presence of `\` in a Lit means a possible escape we can't safely
#     interpret)
#   - SglQuoted (single quotes do zero shell expansion — .Value is the
#     literal byte-for-byte string, even backslashes)
#   - DblQuoted whose inner Parts are all Lit (no $, no `, no expansion;
#     same backslash caveat as top-level Lit)
# Anything else (ParamExp, CmdSubst, ANSI-C $'...', DblQuoted with any
# expansion inside) → null = opaque, forces ask.
AST=$(shfmt --to-json <<<"$COMMAND" 2>/dev/null) \
  || ask "could not parse command via shfmt"

# CMDS = [[token-or-null, ...], ...] — one inner array per CallExpr.
CMDS=$(jq -c '
  def partValue:
    if .Type == "Lit" then
      if .Value | test("\\\\") then null else .Value end
    elif .Type == "SglQuoted" then
      .Value
    elif .Type == "DblQuoted" and (all(.Parts[]; .Type == "Lit")) then
      ([.Parts[].Value] | add // "") as $j |
      if $j | test("\\\\") then null else $j end
    else null
    end;
  def tokens: [.Parts[] | partValue];
  [.. | objects | select(.Type == "CallExpr") |
    [.Args[]? |
      tokens as $toks |
      if any($toks[]; . == null) then null
      else ($toks | add // "") end]
  ]
' <<<"$AST")

# Token 0 (the command itself) being opaque means we cannot identify what
# is about to run — always ask. Nulls in arg positions are NOT a global
# ask anymore: the prefix matcher below treats them as wildcards, so a
# rule whose tokens are pinned by literals on either side of a null still
# downgrades to ask. This keeps `git "$(echo push)" --force` caught while
# letting `echo $HOME`, `find -name \*.rs`, etc. through.
if echo "$CMDS" | jq -e 'any(.[]; length > 0 and .[0] == null)' >/dev/null; then
  ask "command name is non-literal (variable, substitution, or escape) — review manually"
fi

# Basename of the first token of every CallExpr, computed once and reused
# by the blocked-commands check below and the pipe-fetch check at the end.
ALL_BASES=$(echo "$CMDS" | jq -r '.[][0] // empty | split("/") | last')

while IFS= read -r base; do
  [ -z "$base" ] && continue
  if echo "$BLOCKED_CMDS_JSON" | jq -e --arg b "$base" 'any(. == $b)' >/dev/null; then
    ask "$base detected. Confirm with user before proceeding."
  fi
done <<<"$ALL_BASES"

# Subcommand prefix match. Each rule "git push" splits into tokens
# ["git" "push"] and matches a CallExpr whose first N args are exactly those
# (exactMatch), or whose literal tokens match and rule-covered positions
# contain only nulls or matching literals (couldMatch). Whitespace in the
# input collapses cleanly; env-var prefixes don't fool us because shfmt
# parses them as Assigns, not Args.
#
# Lines: "deny <rule>" (definite deny), "ask <rule>" (definite ask),
# "wildcard <rule>" (rule could be smuggled via expansion → ask).
# Order in the output is the order we want the bash loop to hit them.
MATCHES=$(jq -nr \
  --argjson cmds "$CMDS" \
  --argjson denyRules "$DENIED_SUBCMDS_JSON" \
  --argjson askRules "$BLOCKED_SUBCMDS_JSON" '
  def tokenize: split(" ");
  def exactMatch($rule; $prefix):
    ($rule | length) as $n |
    ($prefix | length) >= $n
    and ($prefix[:$n]) == $rule;
  # Nulls in rule-covered positions are wildcards. Only used to downgrade
  # to ask, never to deny — we are not certain the rule actually matches.
  def couldMatch($rule; $prefix):
    ($rule | length) as $n |
    ($prefix | length) >= $n
    and all(range($n); $prefix[.] == null or $prefix[.] == $rule[.]);
  def firstExact($rules; $prefix):
    first(
      $rules[] as $r |
      select(exactMatch($r | tokenize; $prefix)) |
      $r
    ) // empty;
  def firstCould($rules; $prefix):
    first(
      $rules[] as $r |
      select(couldMatch($r | tokenize; $prefix)) |
      $r
    ) // empty;
  $cmds[] |
    select(length > 0 and .[0] != null) as $prefix |
    # $prefix[0] is guaranteed literal — the global guard asks upstream
    # when it is null, so rule[0] comparisons here are sound.
    (firstExact($denyRules; $prefix) | "deny " + .),
    (firstExact($askRules; $prefix) | "ask " + .),
    (firstCould($denyRules; $prefix) | "wildcard " + .),
    (firstCould($askRules; $prefix) | "wildcard " + .)
')

while IFS= read -r line; do
  [ -z "$line" ] && continue
  action=${line%% *}
  rule=${line#* }
  case $action in
    deny) deny "Command '$rule' is denied." ;;
    ask) ask "Command '$rule' requires confirmation." ;;
    wildcard) ask "Command may match '$rule' (contains expansion or escape) — review." ;;
  esac
done <<<"$MATCHES"

# Pipe-fetch detection. Deny if any source command and any sink interpreter
# both appear as CallExpr basenames in the same command sequence —
# catches `curl x | sh`, `curl x; bash /tmp/x`, `wget x && python3 /tmp/x`.
src_hit=""
while IFS= read -r src; do
  [ -z "$src" ] && continue
  if grep -qFx "$src" <<<"$ALL_BASES"; then src_hit=$src; break; fi
done < <(echo "$PIPE_SOURCES_JSON" | jq -r '.[]')

if [ -n "$src_hit" ]; then
  while IFS= read -r sink; do
    [ -z "$sink" ] && continue
    if grep -qFx "$sink" <<<"$ALL_BASES"; then
      deny "Pipe-fetch detected ($src_hit + $sink in command sequence)."
    fi
  done < <(echo "$PIPE_SINKS_JSON" | jq -r '.[]')
fi

allow
