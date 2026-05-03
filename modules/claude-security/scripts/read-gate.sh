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

# Normalize: realpath -m handles non-existent components.
NORM_PATH=$(realpath -m -- "$FILE_PATH" 2>/dev/null || printf '%s' "$FILE_PATH")

# File must exist and be a regular file. Use the normalized path so
# the existence check matches what we hash and key the cache on.
if [[ ! -f "$NORM_PATH" ]]; then
  exit 0
fi

SESSION_HASH=$(echo -n "$SESSION_ID" | sha256sum | cut -c1-16)

# Two-level cache layout: <session>/<path-hash>/<slice-hash>. Keying the slice
# under a per-path subdirectory lets edit-track invalidate every slice of a
# modified file by removing the whole path-hash dir.
PATH_HASH=$(printf '%s' "$NORM_PATH" | sha256sum | cut -c1-16)
SLICE_HASH=$(printf '%s|%s' "${OFFSET:-0}" "${LIMIT:-0}" | sha256sum | cut -c1-16)

CACHE_DIR="${HOME}/.claude/read-once/${SESSION_HASH}/${PATH_HASH}"
CACHE_FILE="${CACHE_DIR}/${SLICE_HASH}"

mkdir -p "$CACHE_DIR"

CURRENT_HASH=$(sha256sum "$NORM_PATH" | cut -c1-64)

if [[ -f "$CACHE_FILE" ]]; then
  CACHED_HASH=$(cat "$CACHE_FILE")
  if [[ "$CACHED_HASH" == "$CURRENT_HASH" ]]; then
    BASENAME=$(basename "$NORM_PATH")
    jq -n --arg reason "read-once: ${BASENAME} unchanged (sha256:${CURRENT_HASH:0:12}…), already in context." \
      '{ hookSpecificOutput: { hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason } }'
    exit 0
  fi
fi

# Cache miss or content changed — allow and update cache
echo -n "$CURRENT_HASH" > "$CACHE_FILE"
exit 0
