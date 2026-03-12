#!/usr/bin/env bash
# Notify when Claude needs input: macOS notification + phone push via ntfy
# Phone setup: install ntfy app, subscribe to your topic

input=$(cat)
title=$(jq -r '.title // "Claude Code"' <<< "$input" 2>/dev/null || echo "Claude Code")
message=$(jq -r '.message // "Waiting for input"' <<< "$input" 2>/dev/null || echo "Waiting for input")

# macOS desktop notification
if [[ "$(uname)" == "Darwin" ]]; then
  osascript -e "display notification \"$message\" with title \"$title\" sound name \"@sound@\""
fi

# Phone push notification via ntfy
if [[ "@ntfyEnabled@" == "true" ]]; then
  NTFY_TOPIC=$(cat @ntfyTopicFile@ 2>/dev/null) || true
  if [[ -n "$NTFY_TOPIC" ]]; then
    curl -sf -o /dev/null -d "$message" -H "Title: $title" -H "Priority: high" "@ntfyServerUrl@/$NTFY_TOPIC" &
  fi
fi
