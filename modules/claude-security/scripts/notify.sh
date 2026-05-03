# Notify when Claude needs input: macOS notification + optional ntfy push.
# Phone setup: install the ntfy app, subscribe to your topic.
#
# Shebang and `set -euo pipefail` are injected by writeShellApplication.

input=$(cat)

title=$(jq -r '.title // "Claude Code"' <<<"$input")
message=$(jq -r '.message // "Waiting for input"' <<<"$input")

if [ "$(uname)" = "Darwin" ]; then
  # Title and message ride env vars; AppleScript reads them via
  # `system attribute`, which can't be smuggled out of string context.
  # /usr/bin/osascript is shipped by macOS — there's no nixpkgs equivalent,
  # and writeShellApplication's cleanPATH won't find a relative `osascript`.
  CLAUDE_TITLE="$title" CLAUDE_MESSAGE="$message" \
    /usr/bin/osascript <<'APPLESCRIPT'
set t to (system attribute "CLAUDE_TITLE")
set m to (system attribute "CLAUDE_MESSAGE")
display notification m with title t sound name "@sound@"
APPLESCRIPT
fi

if [ "@ntfyEnabled@" = "true" ]; then
  NTFY_TOPIC=""
  if [ -n "@ntfyTopicFile@" ] && [ -r "@ntfyTopicFile@" ]; then
    # Strip anything outside the ntfy topic charset. `-` is last in the
    # class so it's literal, not a range.
    NTFY_TOPIC=$(tr -dc 'A-Za-z0-9_-' <"@ntfyTopicFile@" || true)
  fi
  if [ -n "$NTFY_TOPIC" ] && [ -n "@ntfyServerUrl@" ]; then
    url="@ntfyServerUrl@/$NTFY_TOPIC"
    timeout 5 curl -fsS -H "Title: $title" -d "$message" "$url" \
      >/dev/null 2>&1 || true
  fi
fi
