#!/usr/bin/env bash
# PostToolUse hook: drop the read-once cache for a file we just modified
# so the next Read can see the new content.

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

# realpath -m tolerates non-existent components.
NORM_PATH=$(realpath -m -- "$FILE_PATH" 2>/dev/null || printf '%s' "$FILE_PATH")

SESSION_HASH=$(echo -n "$SESSION_ID" | sha256sum | cut -c1-16)
PATH_HASH=$(printf '%s' "$NORM_PATH" | sha256sum | cut -c1-16)

# Wipes every slice for this file in one shot (read-gate keys slices
# under <session>/<path>/<slice>).
CACHE_PATH_DIR="${HOME}/.claude/read-once/${SESSION_HASH}/${PATH_HASH}"

rm -rf "$CACHE_PATH_DIR"
exit 0
