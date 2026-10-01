# Shared fixtures for the wayfinder-ticket cases. Later tasks reuse these names.

fail() {
  echo "assertion failed: $*" >&2
  exit 1
}

# Exit 77 makes run.sh print `skip`.
skip_if_agent_ancestor() {
  if [ "$WT_AGENT_ANCESTOR" = 1 ]; then
    echo "skipped: a real agent process is an ancestor" >&2
    exit 77
  fi
}

mk_origin() {
  local seed
  seed=$(mktemp -d)
  git init -q --bare -b main origin.git
  git -C "$seed" init -q -b main
  echo seed >"$seed/README"
  git -C "$seed" add README
  git -C "$seed" commit -qm init
  git -C "$seed" push -q "$PWD/origin.git" main
  rm -rf "$seed"
}

mk_clone() {
  git clone -q "file://$PWD/origin.git" repo
  cd repo
}

mk_bclone() {
  bash "$BCLONE" "file://$PWD/origin.git" >/dev/null 2>&1
  cd origin/main
}

new_session() {
  AGENT_SESSION_ID="test-$RANDOM-$RANDOM"
  sleep 600 >/dev/null 2>&1 &
  WAYFINDER_AGENT_PID=$!
  export AGENT_SESSION_ID WAYFINDER_AGENT_PID
}

kill_agent() {
  kill "$WAYFINDER_AGENT_PID" 2>/dev/null || true
  wait "$WAYFINDER_AGENT_PID" 2>/dev/null || true
}

map_path() {
  echo "$(git rev-parse --path-format=absolute --git-common-dir)/wayfinder/$1"
}

wait_unlocked() {
  local f i
  f=$(map_path "$1")/$2.claim
  for i in $(seq 80); do
    if flock -n "$f" true; then
      return 0
    fi
    sleep 0.1
  done
  fail "claim lock on $1#$2 still held after 8s"
}

# Writes stdin (or the given text) to a fresh temp file and prints its path.
text_file() {
  local f
  f=$(mktemp)
  if [ $# -gt 0 ]; then
    printf '%s\n' "$1" >"$f"
  else
    cat >"$f"
  fi
  echo "$f"
}

mk_map() {
  "$WT" map-new "$1" "Map $1" --destination "$(text_file "Destination of $1")"
  echo "$1"
}

mk_ticket() {
  local slug=$1 type=$2
  shift 2
  "$WT" new "$slug" "$type" "Ticket $type" "$@"
}

assert_eq() {
  [ "$1" = "$2" ] || fail "${3:-values differ}: expected [$2], got [$1]"
}

assert_contains() {
  case $1 in
  *"$2"*) ;;
  *) fail "${3:-missing text}: [$2] not in [$1]" ;;
  esac
}

assert_not_contains() {
  case $1 in
  *"$2"*) fail "${3:-unexpected text}: [$2] in [$1]" ;;
  esac
}

# Runs the command, sets OUT and ERR, and checks the exit code. A rejection must
# print exactly one stderr line.
assert_exit() {
  local want=$1 rc=0 errf
  shift
  errf=$(mktemp)
  OUT=$("$@" 2>"$errf") || rc=$?
  ERR=$(cat "$errf")
  rm -f "$errf"
  [ "$rc" = "$want" ] || fail "expected exit $want, got $rc from: $* (stderr: $ERR)"
  if [ "$want" != 0 ]; then
    [ "$(printf '%s\n' "$ERR" | wc -l | tr -d ' ')" = 1 ] || fail "expected one stderr line from: $* (stderr: $ERR)"
  fi
}

tree_hash() {
  (cd "$1" && find . -print | LC_ALL=C sort | while IFS= read -r p; do
    if [ -f "$p" ]; then
      printf '%s %s\n' "$p" "$(sha256sum <"$p")"
    else
      printf '%s\n' "$p"
    fi
  done) | sha256sum
}

assert_unchanged() {
  local dir=$1 before after
  shift
  before=$(tree_hash "$dir")
  "$@"
  after=$(tree_hash "$dir")
  [ "$before" = "$after" ] || fail "$dir changed after: $*"
}

fm_field() {
  "$WT" show "$1" | awk -v k="$2" 'NR > 1 && /^---$/ { n++; next } n == 1 && index($0, k ": ") == 1 { print substr($0, length(k) + 3) }'
}

status_field() {
  "$WT" status "$1" | awk -v k="$2" 'index($0, k ": ") == 1 { print substr($0, length(k) + 3); found = 1 } index($0, k ":") == 1 && length($0) == length(k) + 1 { found = 1 }'
}
