valid_type() {
  case $1 in
  research:fact | research:options | grilling | prototype | task | implementation) return 0 ;;
  esac
  return 1
}

initial_phase() {
  case $1 in
  research:options) printf 'research\n' ;;
  implementation) printf 'superpowers:brainstorming\n' ;;
  *) printf '\n' ;;
  esac
}

legal_edge() {
  case "$1>$2" in
  "research>wayfinder:resolve" | \
    "superpowers:brainstorming>superpowers:writing-plans" | \
    "superpowers:writing-plans>superpowers:executing-plans")
    return 0
    ;;
  esac
  return 1
}

has_frontmatter() {
  tr -d '\r' <"$1" | awk '
    NR == 1 { if ($0 != "---") exit 1; next }
    $0 == "---" { found = 1; exit }
    END { exit !found }
  '
}

# shellcheck disable=SC2016
TICKET_FIELDS='select(tag == "!!map") |
  "T_ID=" + ((.id // "") | tostring | @sh) + "\n" +
  "T_TYPE=" + ((.type // "") | tostring | @sh) + "\n" +
  "T_TITLE=" + ((.title // "") | tostring | @sh) + "\n" +
  "T_STATUS=" + ((.status // "") | tostring | @sh) + "\n" +
  "T_PHASE=" + ((.phase // "") | tostring | @sh) + "\n" +
  "T_BLOCKED_TAG=" + ((.["blocked-by"] // []) | tag | @sh) + "\n" +
  "T_BLOCKED=" + ((.["blocked-by"] // []) | map(tostring) | join(" ") | @sh) + "\n" +
  "T_CLAIMED=" + ((.["claimed-by"] // "") | tostring | @sh) + "\n" +
  "T_SPEC=" + ((.spec // "") | tostring | @sh) + "\n" +
  "T_PLAN=" + ((.plan // "") | tostring | @sh) + "\n" +
  "T_BRANCH=" + ((.branch // "") | tostring | @sh) + "\n" +
  "T_SUPERSEDED=" + ((.["superseded-by"] // "") | tostring | @sh) + "\n" +
  "T_FINDINGS=" + ((.findings // "") | tostring | @sh) + "\n" +
  "T_LOADED=1"'

# load_ticket <file> <id>: sets the T_* fields, rejecting malformed frontmatter.
load_ticket() {
  local file=$1 id=$2 out b
  # shellcheck disable=SC2034
  T_ID='' T_TYPE='' T_TITLE='' T_STATUS='' T_PHASE='' T_BLOCKED_TAG='' T_BLOCKED='' T_CLAIMED=''
  # shellcheck disable=SC2034
  T_SPEC='' T_PLAN='' T_BRANCH='' T_SUPERSEDED='' T_FINDINGS='' T_LOADED=''
  has_frontmatter "$file" || die 1 "malformed frontmatter in $file"
  out=$(tr -d '\r' <"$file" | yq --front-matter=extract "$TICKET_FIELDS" - 2>/dev/null) ||
    die 1 "malformed frontmatter in $file"
  eval "$out"
  [ "$T_LOADED" = 1 ] || die 1 "malformed frontmatter in $file"
  [ "$T_ID" = "$id" ] || die 1 "malformed frontmatter in $file: id is '$T_ID'"
  valid_type "$T_TYPE" || die 1 "malformed frontmatter in $file: type is '$T_TYPE'"
  case $T_STATUS in
  open | closed) ;;
  *) die 1 "malformed frontmatter in $file: status is '$T_STATUS'" ;;
  esac
  [ "$T_BLOCKED_TAG" = '!!seq' ] || die 1 "malformed frontmatter in $file: blocked-by is not a list"
  for b in $T_BLOCKED; do
    [[ $b =~ $ID_RE ]] || die 1 "malformed frontmatter in $file: blocked-by has '$b'"
  done
}

# shellcheck disable=SC2016
MAP_FIELDS='select(tag == "!!map") |
  "M_SLUG=" + ((.slug // "") | tostring | @sh) + "\n" +
  "M_TITLE=" + ((.title // "") | tostring | @sh) + "\n" +
  "M_STATUS=" + ((.status // "") | tostring | @sh) + "\n" +
  "M_LOADED=1"'

load_map() {
  local file=$1 slug=$2 out
  # shellcheck disable=SC2034
  M_SLUG='' M_TITLE='' M_STATUS='' M_LOADED=''
  has_frontmatter "$file" || die 1 "malformed frontmatter in $file"
  out=$(tr -d '\r' <"$file" | yq --front-matter=extract "$MAP_FIELDS" - 2>/dev/null) ||
    die 1 "malformed frontmatter in $file"
  eval "$out"
  [ "$M_LOADED" = 1 ] || die 1 "malformed frontmatter in $file"
  [ "$M_SLUG" = "$slug" ] || die 1 "malformed frontmatter in $file: slug is '$M_SLUG'"
  case $M_STATUS in
  active | complete) ;;
  *) die 1 "malformed frontmatter in $file: status is '$M_STATUS'" ;;
  esac
}

# use_map <slug> [<ref for messages>]: sets MAP_DIR and MAP_FILE; exit 3 if absent.
use_map() {
  need_repo
  MAP_DIR=$(map_dir "$1")
  MAP_FILE=$MAP_DIR/map.md
  [ -f "$MAP_FILE" ] || die 3 "not found: ${2:-$1}"
}

# use_ticket <ref>: parses the ref and sets SLUG, ID, MAP_DIR, TICKET_FILE, CLAIM_FILE.
use_ticket() {
  parse_ref "$1"
  use_map "$SLUG" "$1"
  TICKET_FILE=$MAP_DIR/$ID.md
  CLAIM_FILE=$MAP_DIR/$ID.claim
  [ -f "$TICKET_FILE" ] || die 3 "not found: $1"
}

# ticket_ids <map dir>: ids in numeric order.
ticket_ids() {
  local f id
  for f in "$1"/*.md; do
    [ -f "$f" ] || continue
    id=$(basename "$f" .md)
    if [[ $id =~ $ID_RE ]]; then
      printf '%s\n' "$id"
    fi
  done | sort -n
}

ticket_exists() {
  [ -f "$MAP_DIR/$1.md" ]
}

# claim_live <claim file>: true when a holder has the lock. Callers hold map.write.
claim_live() {
  [ -e "$1" ] || return 1
  if flock -n "$1" true 2>/dev/null; then
    return 1
  fi
  return 0
}

# claim_state <claim file> <claimed-by>: none, live or stale.
claim_state() {
  if [ -z "$2" ]; then
    printf 'none\n'
  elif claim_live "$1"; then
    printf 'live\n'
  else
    printf 'stale\n'
  fi
}

declare -A GRAPH=()
declare -A STATUS_OF=()

# load_graph: GRAPH[id] is the blocked-by list and STATUS_OF[id] the status of
# every ticket in MAP_DIR.
load_graph() {
  local id out
  GRAPH=()
  STATUS_OF=()
  for id in $(ticket_ids "$MAP_DIR"); do
    out=$(tr -d '\r' <"$MAP_DIR/$id.md" | yq --front-matter=extract \
      '((.status // "") | tostring) + " " + ((.["blocked-by"] // []) | map(tostring) | join(" "))' - 2>/dev/null) ||
      die 1 "malformed frontmatter in $MAP_DIR/$id.md"
    STATUS_OF[$id]=${out%% *}
    GRAPH[$id]=${out#* }
  done
}

# reaches <from> <to>: <to> is reachable from <from> along blocked-by edges
# (or is <from> itself).
reaches() {
  local node next
  local -A seen=()
  local todo=("$1")
  while [ ${#todo[@]} -gt 0 ]; do
    node=${todo[-1]}
    unset 'todo[-1]'
    [ "$node" != "$2" ] || return 0
    [ -z "${seen[$node]:-}" ] || continue
    seen[$node]=1
    for next in ${GRAPH[$node]:-}; do
      todo+=("$next")
    done
  done
  return 1
}

set_blocked() {
  local file=$1
  shift
  WT_VALUE=$(yaml_id_list "$@") fm_update "$file" \
    '.["blocked-by"] = (strenv(WT_VALUE) | from_yaml) | .["blocked-by"] style = "flow"'
}

# yaml_id_list <id>...: a flow list of unique ids in numeric order.
yaml_id_list() {
  local ids
  ids=$(printf '%s\n' "$@" | awk 'NF' | sort -nu | paste -sd, -)
  printf '[%s]\n' "$ids"
}

# stage_copy <var> <file>: a working copy beside <file>; commit_stage renames it back.
stage_copy() {
  local f
  f=$(mktemp "$(dirname "$2")/.stage.XXXXXX" 2>/dev/null) || die 1 "cannot write in $(dirname "$2")"
  TMPFILES+=("$f")
  cp "$2" "$f" 2>/dev/null || die 1 "cannot write $f"
  printf -v "$1" '%s' "$f"
}

commit_stage() {
  mv -f "$1" "$2" 2>/dev/null || die 1 "cannot write $2"
}

ticket_title_ok() {
  [ -n "$1" ] || die 1 "title is empty"
  [[ $1 != *$'\n'* && $1 != *$'\r'* ]] || die 1 "title must be one line"
}
