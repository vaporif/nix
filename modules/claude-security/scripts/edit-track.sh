#!/usr/bin/env bash
# PostToolUse hook: invalidate read-once cache when a file is modified.
# Ensures the next Read after an Edit/Write goes through.

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

if [[ "$TOOL_NAME" != "Edit" && "$TOOL_NAME" != "Write" ]]; then
  exit 0
fi

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

if [[ -z "$FILE_PATH" || -z "$SESSION_ID" ]]; then
  exit 0
fi

# Normalize: realpath -m handles non-existent components.
NORM_PATH=$(realpath -m -- "$FILE_PATH" 2>/dev/null || printf '%s' "$FILE_PATH")

SESSION_HASH=$(echo -n "$SESSION_ID" | sha256sum | cut -c1-16)
PATH_HASH=$(printf '%s' "$NORM_PATH" | sha256sum | cut -c1-16)

CACHE_FILE="${HOME}/.claude/read-once/${SESSION_HASH}/${PATH_HASH}"

rm -f "$CACHE_FILE"
exit 0
