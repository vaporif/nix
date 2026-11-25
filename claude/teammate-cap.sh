#!/usr/bin/env bash
# PreToolUse hook (matcher: Agent): refuse to spawn a teammate once
# CLAUDE_MAX_TEAMMATES are alive. An Agent call with `name` starts a teammate
# unless it is a fork or isolated; anything else is an ordinary subagent.
#
# Teammates are counted as live processes started with `--agent-id`. Inside
# the Linux sandbox the PID namespace holds only this lead's team, so the cap
# is per team; elsewhere (darwin, unsandboxed) it counts every team on the box.
input=$(cat)

name=$(jq -r '.tool_input.name // empty' <<<"$input")
[[ -z $name ]] && exit 0
[[ -n $(jq -r '.tool_input.isolation // empty' <<<"$input") ]] && exit 0
[[ $(jq -r '.tool_input.subagent_type // empty' <<<"$input") == fork ]] && exit 0

max=${CLAUDE_MAX_TEAMMATES:-3}
live=$( (pgrep -f -- '--agent-id [^ ]+@' || true) | wc -l)
((live < max)) && exit 0

jq -nc --arg reason "Teammate cap reached: $live of $max teammates are running. Reuse an idle teammate via SendMessage, or shut one down before spawning \"$name\"." '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
