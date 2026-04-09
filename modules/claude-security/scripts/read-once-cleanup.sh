#!/usr/bin/env bash
# SessionStart hook: clean up read-once cache dirs older than 24h.

CACHE_DIR="${HOME}/.claude/read-once"

if [[ -d "$CACHE_DIR" ]]; then
  find "$CACHE_DIR" -mindepth 1 -maxdepth 1 -type d -mtime +1 -exec rm -rf {} + 2>/dev/null || true
fi

exit 0
