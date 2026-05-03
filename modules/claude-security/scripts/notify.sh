# Notify when Claude needs input: macOS notification + phone push via ntfy
# Phone setup: install ntfy app, subscribe to your topic
#
# Shebang and `set -euo pipefail` are intentionally omitted —
# writeShellApplication injects them.

input=$(cat)

title=$(jq -r '.title // "Claude Code"' <<<"$input")
message=$(jq -r '.message // "Waiting for input"' <<<"$input")

if [ "$(uname)" = "Darwin" ]; then
  # Pass values via env; AppleScript reads them with `system attribute`,
  # which is string-clean and cannot be smuggled into the script body.
  # /usr/bin/osascript is part of macOS itself; pkgs.darwin.osascript
  # does not exist as a nix attribute. writeShellApplication uses cleanPATH,
  # so use the absolute path.
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
    # Strip any character outside the ntfy topic charset.
    # `-` is last in the class so it's literal, not a range marker.
    NTFY_TOPIC=$(tr -dc 'A-Za-z0-9_-' <"@ntfyTopicFile@" || true)
  fi
  if [ -n "$NTFY_TOPIC" ] && [ -n "@ntfyServerUrl@" ]; then
    url="@ntfyServerUrl@/$NTFY_TOPIC"
    timeout 5 curl -fsS -H "Title: $title" -d "$message" "$url" \
      >/dev/null 2>&1 || true
  fi
fi
