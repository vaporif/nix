#!/usr/bin/env bash
# macOS notification when Claude needs input
[[ "$(uname)" != "Darwin" ]] && exit 0

input=$(cat)
title=$(jq -r '.title // "Claude Code"' <<< "$input" 2>/dev/null || echo "Claude Code")
message=$(jq -r '.message // "Waiting for input"' <<< "$input" 2>/dev/null || echo "Waiting for input")

osascript -e "display notification \"$message\" with title \"$title\" sound name \"Glass\""
