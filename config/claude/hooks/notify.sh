#!/usr/bin/env bash
# macOS notification when Claude needs input
[[ "$(uname)" != "Darwin" ]] && exit 0

input=$(cat)
title=$(echo "$input" | jq -r '.title // "Claude Code"')
message=$(echo "$input" | jq -r '.message // "Waiting for input"')

osascript -e "display notification \"$message\" with title \"$title\" sound name \"Glass\""
