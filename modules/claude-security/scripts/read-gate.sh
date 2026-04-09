#!/usr/bin/env bash
# PreToolUse hook: deny Read when file content hasn't changed since last read.
# Uses sha256 of file content (not mtime) for accurate change detection.
# Cache is session-scoped: ~/.claude/read-once/<session-hash>/<path-hash>

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

if [[ "$TOOL_NAME" != "Read" ]]; then
  exit 0
fi

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
OFFSET=$(echo "$INPUT" | jq -r '.tool_input.offset // empty')
LIMIT=$(echo "$INPUT" | jq -r '.tool_input.limit // empty')

if [[ -z "$FILE_PATH" || -z "$SESSION_ID" ]]; then
  exit 0
fi

# Partial reads are never cached — each chunk is different content
if [[ -n "$OFFSET" || -n "$LIMIT" ]]; then
  exit 0
fi

# File must exist and be a regular file
if [[ ! -f "$FILE_PATH" ]]; then
  exit 0
fi

SESSION_HASH=$(echo -n "$SESSION_ID" | shasum -a 256 | cut -c1-16)
PATH_HASH=$(echo -n "$FILE_PATH" | shasum -a 256 | cut -c1-16)

CACHE_DIR="${HOME}/.claude/read-once/${SESSION_HASH}"
CACHE_FILE="${CACHE_DIR}/${PATH_HASH}"

mkdir -p "$CACHE_DIR"

CURRENT_HASH=$(shasum -a 256 "$FILE_PATH" | cut -c1-64)

if [[ -f "$CACHE_FILE" ]]; then
  CACHED_HASH=$(cat "$CACHE_FILE")
  if [[ "$CACHED_HASH" == "$CURRENT_HASH" ]]; then
    BASENAME=$(basename "$FILE_PATH")
    jq -n --arg reason "read-once: ${BASENAME} unchanged (sha256:${CURRENT_HASH:0:12}…), already in context." \
      '{ hookSpecificOutput: { hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason } }'
    exit 0
  fi
fi

# Cache miss or content changed — allow and update cache
echo -n "$CURRENT_HASH" > "$CACHE_FILE"
exit 0
