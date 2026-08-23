# Visual state indicator: rewrites the terminal tab title from Claude Code
# hooks so a background tab tells you what that session is doing —
# working, waiting on you, or finished. Replaces Claude's own topic title
# (settings.nix sets CLAUDE_CODE_DISABLE_TERMINAL_TITLE so the two don't
# fight over OSC 2).
#
# Hooks receive their event JSON on stdin. Nothing may be written to stdout:
# a UserPromptSubmit hook's stdout is injected into the conversation as
# context, so the title escape has to go straight to the terminal device.

input=$(cat)

event=$(jq -r '.hook_event_name // ""' <<<"$input" 2>/dev/null)
cwd=$(jq -r '.cwd // ""' <<<"$input" 2>/dev/null)

case "$event" in
  UserPromptSubmit | PreToolUse | PostToolUse | SubagentStop) glyph="⠿" ;;
  Notification) glyph="?" ;;
  Stop) glyph="✓" ;;
  SessionStart) glyph="·" ;;
  SessionEnd) glyph="" ;;
  *) exit 0 ;;
esac

label="claude"
if [ -n "$cwd" ]; then
  label=$(basename "$cwd")
fi

title="$label"
if [ -n "$glyph" ]; then
  title="$glyph $label"
fi

# The hook usually has no controlling terminal of its own, so walk up the
# process tree until something still holds the pty Claude was launched on.
resolve_terminal() {
  # Grouped so the failed redirection's own message is silenced too.
  if {
    : >/dev/tty
  } 2>/dev/null; then
    printf '%s' /dev/tty
    return 0
  fi

  pid=$$
  depth=0
  while [ -n "$pid" ] && [ "$pid" -gt 0 ] 2>/dev/null && [ "$depth" -lt 12 ]; do
    # Under the bubblewrap sandbox the pty is unreachable by path — /dev/pts
    # isn't shared into the namespace — but the inherited fd still is. The
    # char-device test skips the hook's own piped stdout; /dev/null is a
    # char device too, hence the explicit exclusion.
    fd="/proc/$pid/fd/1"
    if [ -c "$fd" ] && [ -w "$fd" ] && [ "$(readlink "$fd" 2>/dev/null)" != "/dev/null" ]; then
      printf '%s' "$fd"
      return 0
    fi

    # darwin has no /proc; there `ps` names the tty ("ttys003") and it
    # resolves under /dev directly. "?"/"??" means the process has none.
    dev=$(ps -o tty= -p "$pid" 2>/dev/null | tr -d '[:space:]')
    if [ -n "$dev" ] && [ "$dev" != "?" ] && [ "$dev" != "??" ] && [ -w "/dev/$dev" ]; then
      printf '%s' "/dev/$dev"
      return 0
    fi

    pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d '[:space:]')
    depth=$((depth + 1))
  done
  return 1
}

terminal=$(resolve_terminal) || exit 0

# Two sequences, because the session may or may not have a tmux between it
# and the terminal — and here it usually does, since ghostty on the mac
# launches tmux as its command and this VM is reached over ssh from there.
#
#   OSC 2      sets the pane title (#T). ghostty renders it as the tab title
#              when nothing intercepts it, but tmux only surfaces #T for the
#              *active* pane, which is useless for a backgrounded session.
#   ESC k      renames the tmux window (#W) — what the status bar actually
#              draws for every window, focused or not. Needs `allow-rename
#              on`; terminals that aren't tmux ignore it.
{
  printf '\033]2;%s\007' "$title"
  # shellcheck disable=SC1003  # the \\ is printf's escape for the ST byte
  printf '\033k%s\033\\' "$title"
} >"$terminal" 2>/dev/null || true
