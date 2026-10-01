NO_AGENT="no agent process found (looked for .claude-unwrapped, claude, codex-raw, codex)"

line_of() {
  awk -v n="$2" 'NR == n { print; exit }' "$1"
}

on_linux() {
  [ -r /proc/self/stat ]
}

# proc_name <pid>: the executable's basename. Linux reads /proc/<pid>/exe since
# comm is cut to 15 characters; macOS asks ps for comm on its own, because as a
# non-final column it is cut to 16.
proc_name() {
  local exe
  if on_linux; then
    exe=$(readlink "/proc/$1/exe" 2>/dev/null) || return 1
    exe=${exe% (deleted)}
  else
    exe=$(ps -o comm= -p "$1" 2>/dev/null) || return 1
  fi
  [ -n "$exe" ] || return 1
  basename -- "$exe"
}

proc_ppid() {
  local p
  p=$(ps -o ppid= -p "$1" 2>/dev/null) || return 1
  p=${p//[[:space:]]/}
  [ -n "$p" ] || return 1
  printf '%s\n' "$p"
}

is_agent_name() {
  case $1 in
  .claude-unwrapped | claude | codex-raw | codex) return 0 ;;
  esac
  return 1
}

# agent_walk: "<pid> <name>" of the first agent process among our ancestors.
agent_walk() {
  local pid=$PPID name
  while [ -n "$pid" ] && [ "$pid" -gt 1 ]; do
    name=$(proc_name "$pid") || name=""
    if is_agent_name "$name"; then
      printf '%s %s\n' "$pid" "$name"
      return 0
    fi
    pid=$(proc_ppid "$pid") || return 1
  done
  return 1
}

# agent_pid: WAYFINDER_AGENT_PID when set, otherwise the process walk.
agent_pid() {
  local found
  if [ -n "${WAYFINDER_AGENT_PID:-}" ]; then
    if ! [[ $WAYFINDER_AGENT_PID =~ $ID_RE ]] || ! kill -0 "$WAYFINDER_AGENT_PID" 2>/dev/null; then
      die 1 "$NO_AGENT"
    fi
    printf '%s\n' "$WAYFINDER_AGENT_PID"
    return
  fi
  found=$(agent_walk) || die 1 "$NO_AGENT"
  printf '%s\n' "${found%% *}"
}

# agent_start <pid>: /proc stat field 22 on Linux, ps lstart on macOS.
agent_start() {
  local stat rest
  if [ -n "${WAYFINDER_AGENT_START:-}" ]; then
    printf '%s\n' "$WAYFINDER_AGENT_START"
    return
  fi
  if on_linux; then
    stat=$(cat "/proc/$1/stat" 2>/dev/null) || return 1
    # Fields after the parenthesised comm start at field 3, so field 22 is the 20th.
    rest=${stat##*) }
    awk '{ print $20 }' <<<"$rest"
  else
    stat=$(ps -o lstart= -p "$1" 2>/dev/null) || return 1
    stat=$(printf '%s' "$stat" | awk '{ $1 = $1; print }')
    [ -n "$stat" ] || return 1
    printf '%s\n' "$stat"
  fi
}

agent_alive() {
  local now
  kill -0 "$1" 2>/dev/null || return 1
  now=$(agent_start "$1") || return 1
  [ "$now" = "$2" ]
}

check_session_id() {
  [ -n "$SID" ] || die 1 "AGENT_SESSION_ID is not set; start the agent through claude-sandboxed or codex-sandboxed"
  [[ $SID =~ ^[A-Za-z0-9._-]+$ ]] || die 1 "AGENT_SESSION_ID has unexpected characters: $SID"
}

pid_file_for() {
  printf '%s/wayfinder-%s/%s-%s.pid\n' "${TMPDIR:-/tmp}" "$SID" "$1" "$2"
}

# open_blockers: the ids in T_BLOCKED whose tickets are not closed.
open_blockers() {
  local b status
  for b in $T_BLOCKED; do
    if [ -f "$MAP_DIR/$b.md" ]; then
      status=$(fm_get "$MAP_DIR/$b.md" status) || status=""
      if [ "$status" = closed ]; then
        continue
      fi
    fi
    printf '%s\n' "$b"
  done
}

claim_guards() {
  local ref=$1 phase=$2 blockers
  [ "$T_STATUS" = open ] || die 4 "ticket closed: $ref"
  blockers=$(open_blockers | paste -sd, -)
  [ -z "$blockers" ] || die 7 "blocked by $blockers"
  if [ -n "$phase" ] && [ "$T_PHASE" != "$phase" ]; then
    die 5 "phase is ${T_PHASE:--}, expected $phase"
  fi
}

# require_owner <ref>: this session holds a live claim on the loaded ticket.
require_owner() {
  if [ -n "$SID" ] && [ "$T_CLAIMED" = "$SID" ] && claim_live "$CLAIM_FILE"; then
    return 0
  fi
  if [ -n "$T_CLAIMED" ] && claim_live "$CLAIM_FILE"; then
    die 6 "claimed by another session ($T_CLAIMED)"
  fi
  die 1 "not owner of $1"
}

# stop_own_holder <ref>: signal this session's holder and wait for the lock on
# fd 9. Callers hold map.write and have checked ownership.
stop_own_holder() {
  local pidfile holder agent recorded now
  pidfile=$(pid_file_for "$SLUG" "$ID")
  if [ -f "$pidfile" ]; then
    holder=$(line_of "$pidfile" 1)
    agent=$(line_of "$pidfile" 2)
    recorded=$(line_of "$pidfile" 3)
    now=$(agent_start "$agent" 2>/dev/null) || now=""
    # A changed start time means the holder already exited and its PID may be reused.
    if [ -n "$holder" ] && [ "$now" = "$recorded" ]; then
      kill "$holder" 2>/dev/null || true
    fi
  fi
  exec 9<"$CLAIM_FILE" || die 1 "cannot open $CLAIM_FILE"
  flock -w 2 9 || die 1 "claim on $1 is still held after 2s; claimed-by left as is"
  rm -f "$pidfile"
}

# release_for_close <ref>: free the claim before a closing write. The ticket is
# either ours and live, or not live at all; callers checked which.
release_for_close() {
  if [ -n "$SID" ] && [ "$T_CLAIMED" = "$SID" ] && claim_live "$CLAIM_FILE"; then
    stop_own_holder "$1"
    return
  fi
  exec 9<"$CLAIM_FILE" || die 1 "cannot open $CLAIM_FILE"
  flock -n 9 || die 6 "claimed by another session (${T_CLAIMED:-unknown})"
}

local_claim() {
  local u="claim <slug>#<id> [--phase <phase>]"
  [ $# -ge 1 ] || usage_error "$u"
  local ref=$1 phase="" agent start previous pidfile self holder i
  shift
  while [ $# -gt 0 ]; do
    case $1 in
    --phase)
      [ $# -ge 2 ] || usage_error "$u"
      phase=$2
      shift 2
      ;;
    *) usage_error "$u" ;;
    esac
  done
  parse_ref "$ref"
  need_repo
  check_session_id
  agent=$(agent_pid)
  start=$(agent_start "$agent") || die 1 "$NO_AGENT"
  use_ticket "$ref"
  lock_map "$SLUG"
  load_ticket "$TICKET_FILE" "$ID"
  if [ ! -e "$CLAIM_FILE" ]; then
    : >"$CLAIM_FILE" 2>/dev/null || die 1 "cannot create $CLAIM_FILE"
  fi
  exec 9<"$CLAIM_FILE" || die 1 "cannot open $CLAIM_FILE"
  if ! flock -n 9; then
    [ "$T_CLAIMED" = "$SID" ] || die 6 "claimed by another session (${T_CLAIMED:-unknown})"
    claim_guards "$ref" "$phase"
    return 0
  fi
  claim_guards "$ref" "$phase"
  previous=$T_CLAIMED
  pidfile=$(pid_file_for "$SLUG" "$ID")
  mkdir -p "$(dirname "$pidfile")" 2>/dev/null || die 1 "cannot create $(dirname "$pidfile")"
  rm -f "$pidfile"
  fm_set_str "$TICKET_FILE" claimed-by "$SID"
  self=$(realpath "$0")
  # The holder keeps fd 9 and nothing else: map.write would block every later
  # command, and an inherited stdout pipe would keep the tool call waiting.
  setsid -f "$self" __hold "$SLUG" "$ID" "$agent" "$start" 8>&- </dev/null >/dev/null 2>&1 ||
    holder_failed "$previous"
  for i in $(seq 100); do
    [ -s "$pidfile" ] && break
    sleep 0.05
    : "$i"
  done
  holder=$(line_of "$pidfile" 1 2>/dev/null) || holder=""
  if [ -z "$holder" ] || ! kill -0 "$holder" 2>/dev/null; then
    holder_failed "$previous"
  fi
  exec 9<&-
  if [ -n "$previous" ] && [ "$previous" != "$SID" ]; then
    printf 'took over stale claim from %s\n' "$previous"
  fi
}

holder_failed() {
  fm_set_str "$TICKET_FILE" claimed-by ""
  die 1 "claim holder did not start for $SLUG#$ID"
}

local_release() {
  local u="release <slug>#<id> [--force]"
  [ $# -ge 1 ] || usage_error "$u"
  local ref=$1 force=0
  shift
  while [ $# -gt 0 ]; do
    case $1 in
    --force)
      force=1
      shift
      ;;
    *) usage_error "$u" ;;
    esac
  done
  parse_ref "$ref"
  need_repo
  [ "$force" = 0 ] || die 1 "release --force is for remote backends; a local claim goes stale once its agent exits"
  use_ticket "$ref"
  lock_map "$SLUG"
  load_ticket "$TICKET_FILE" "$ID"
  require_owner "$ref"
  stop_own_holder "$ref"
  fm_set_str "$TICKET_FILE" claimed-by ""
}

# hold_main <slug> <id> <agent pid> <agent start>: the holder process.
hold_main() {
  local slug=$1 id=$2 agent=$3 start=$4 pidfile recorded
  exec 3>&- 4>&- 5>&- 6>&- 7>&- 8>&-
  pidfile=$(pid_file_for "$slug" "$id")
  agent_alive "$agent" "$start" 9>&- || exit 0
  printf '%s\n%s\n%s\n' "$$" "$agent" "$start" >"$pidfile.$$" 9>&- || exit 0
  mv -f "$pidfile.$$" "$pidfile" 9>&- || exit 0
  while :; do
    sleep 5 9>&-
    [ "$(line_of "$pidfile" 1 2>/dev/null 9>&-)" = "$$" ] || exit 0
    recorded=$(line_of "$pidfile" 3 9>&-)
    agent_alive "$agent" "$recorded" 9>&- || exit 0
  done
}
