# Notify when Claude needs input: macOS notification + optional ntfy push.
# Phone setup: install the ntfy app, subscribe to your topic.
#
# Shebang and `set -euo pipefail` are injected by writeShellApplication.

input=$(cat)

title=$(jq -r '.title // "Claude Code"' <<<"$input")
message=$(jq -r '.message // "Waiting for input"' <<<"$input")

# Nix substitutes these via builtins.replaceStrings. Assigning to variables
# first keeps shellcheck from constant-folding the literals (SC2050/SC2157).
ntfy_enabled="@ntfyEnabled@"
ntfy_topic_file="@ntfyTopicFile@"
ntfy_server_url="@ntfyServerUrl@"

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

if [ "$ntfy_enabled" = "true" ]; then
  NTFY_TOPIC=""
  if [ -n "$ntfy_topic_file" ] && [ -r "$ntfy_topic_file" ]; then
    # Strip anything outside the ntfy topic charset. `-` is last in the
    # class so it's literal, not a range.
    NTFY_TOPIC=$(tr -dc 'A-Za-z0-9_-' <"$ntfy_topic_file" || true)
  fi
  if [ -n "$NTFY_TOPIC" ] && [ -n "$ntfy_server_url" ]; then
    url="$ntfy_server_url/$NTFY_TOPIC"
    timeout 5 curl -fsS -H "Title: $title" -d "$message" "$url" \
      >/dev/null 2>&1 || true
  fi
fi
