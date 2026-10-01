export LC_ALL=C

SLUG_RE='^[a-z0-9][a-z0-9-]*$'
ID_RE='^[1-9][0-9]*$'
SID=${AGENT_SESSION_ID:-}
COMMON=
TMPFILES=()

cleanup_tmpfiles() {
  if [ ${#TMPFILES[@]} -gt 0 ]; then
    rm -rf "${TMPFILES[@]}"
  fi
}
trap cleanup_tmpfiles EXIT

# Every rejection is exactly one stderr line.
die() {
  local code=$1 msg
  shift
  msg=$*
  msg=${msg//$'\r'/}
  msg=${msg//$'\n'/ }
  printf 'wayfinder-ticket: %s\n' "$msg" >&2
  exit "$code"
}

usage_error() {
  die 2 "usage: wayfinder-ticket $*"
}

# new_tmp <var> [-d]: a private temp file (or dir) outside the map dir, removed on exit.
new_tmp() {
  local f
  f=$(mktemp ${2:+"$2"} 2>/dev/null) || die 1 "cannot create a temp file"
  TMPFILES+=("$f")
  printf -v "$1" '%s' "$f"
}

check_slug() {
  [[ $1 =~ $SLUG_RE ]] || die 1 "invalid slug: $1"
}

check_id() {
  [[ $1 =~ $ID_RE ]] || die 1 "invalid id: $1"
}

# parse_ref <slug>#<id>: sets SLUG and ID.
parse_ref() {
  [[ $1 == *'#'* ]] || die 1 "invalid reference: $1 (expected <slug>#<id>)"
  SLUG=${1%%#*}
  ID=${1#*#}
  check_slug "$SLUG"
  check_id "$ID"
}

need_repo() {
  if [ -z "$COMMON" ]; then
    COMMON=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) ||
      die 1 "not inside a git repository"
  fi
}

common_dir() {
  need_repo
  printf '%s\n' "$COMMON"
}

map_dir() {
  printf '%s/wayfinder/%s\n' "$COMMON" "$1"
}

backend() {
  local b
  b=$(git config --default local --get wayfinder.backend 2>/dev/null) || b=local
  case $b in
  local | github | gitlab) printf '%s\n' "$b" ;;
  *) die 1 "unknown wayfinder.backend: $b (expected local, github or gitlab)" ;;
  esac
}

# dispatch <command> [args...]: runs <backend>_<command>.
dispatch() {
  local cmd=$1 b fn
  shift
  b=$(backend)
  fn="${b}_${cmd//-/_}"
  declare -F "$fn" >/dev/null || die 1 "$cmd is not implemented on the $b backend"
  "$fn" "$@"
}

# The map.write lock is fd 8. It is held until the process exits or unlock_map.
lock_map() {
  local dir
  dir=$(map_dir "$1")
  exec 8>>"$dir/map.write" || die 1 "cannot open $dir/map.write"
  flock 8 || die 1 "cannot lock $dir/map.write"
}

unlock_map() {
  exec 8>&-
}

with_map_lock() {
  local slug=$1
  shift
  lock_map "$slug"
  "$@"
}

# write_file <target> <source>: LF-normalised copy, temp file + rename.
write_file() {
  local target=$1 src=$2 tmp
  tmp=$(mktemp "$(dirname "$target")/.tmp.XXXXXX" 2>/dev/null) || die 1 "cannot write in $(dirname "$target")"
  if ! tr -d '\r' <"$src" >"$tmp" 2>/dev/null || ! mv -f "$tmp" "$target" 2>/dev/null; then
    rm -f "$tmp"
    die 1 "cannot write $target"
  fi
}

# fm_update <file> <yq expression>: rewrite the frontmatter in place. Values
# reach the expression through exported variables and strenv().
fm_update() {
  local file=$1 expr=$2 tmp
  tmp=$(mktemp "$(dirname "$file")/.tmp.XXXXXX" 2>/dev/null) || die 1 "cannot write in $(dirname "$file")"
  if ! tr -d '\r' <"$file" | yq --front-matter=process "$expr" - >"$tmp" 2>/dev/null; then
    rm -f "$tmp"
    die 1 "cannot update $file"
  fi
  mv -f "$tmp" "$file" 2>/dev/null || {
    rm -f "$tmp"
    die 1 "cannot write $file"
  }
}

fm_get() {
  tr -d '\r' <"$1" | WT_KEY=$2 yq --front-matter=extract '.[strenv(WT_KEY)] // ""' - 2>/dev/null
}

# fm_set <file> <key> <yaml-value>
fm_set() {
  WT_KEY=$2 WT_VALUE=$3 fm_update "$1" '.[strenv(WT_KEY)] = (strenv(WT_VALUE) | from_yaml)'
}

fm_set_str() {
  WT_KEY=$2 WT_VALUE=$3 fm_update "$1" '.[strenv(WT_KEY)] = strenv(WT_VALUE)'
}

reserved_sections() {
  case $(basename "$1") in
  map.md) printf '%s|' "Destination" "Decisions so far" "Not yet specified" "Out of scope" "Notes" ;;
  *) printf '%s|' "Question" "Notes" "Answer" "Verification evidence" ;;
  esac
}

# section_get <file> <name>: the bytes between the heading and the next
# reserved heading. Other "## " lines are content.
section_get() {
  local reserved
  reserved=$(reserved_sections "$1")
  tr -d '\r' <"$1" | WT_RESERVED=$reserved WT_SECTION=$2 awk '
    BEGIN {
      n = split(ENVIRON["WT_RESERVED"], r, "|")
      for (i = 1; i < n; i++) res["## " r[i]] = 1
      want = "## " ENVIRON["WT_SECTION"]
    }
    fm < 2 { if ($0 == "---") fm++; next }
    $0 in res { on = ($0 == want); next }
    on { print }
  '
}

section_hash() {
  section_get "$1" "$2" | sha256sum | cut -d' ' -f1
}

trim_blank_lines() {
  tr -d '\r' | awk '
    NF { for (i = 1; i <= nb; i++) print held[i]; nb = 0; print; started = 1; next }
    started { held[++nb] = $0 }
  '
}

# prepare_content <var> <source> <kind file>: LF-normalised, trimmed copy of the
# input; rejects a line equal to a reserved heading of that file kind.
prepare_content() {
  local var=$1 src=$2 kind=$3 out name
  if [ ! -r "$src" ] || [ -d "$src" ]; then
    die 1 "cannot read $src"
  fi
  new_tmp out
  trim_blank_lines <"$src" >"$out"
  local IFS='|'
  for name in $(reserved_sections "$kind"); do
    if grep -qxF -- "## $name" "$out"; then
      die 1 "content contains section heading: ## $name"
    fi
  done
  printf -v "$var" '%s' "$out"
}

# section_set <file> <name> <prepared content file>
section_set() {
  local file=$1 tmp reserved
  reserved=$(reserved_sections "$file")
  tmp=$(mktemp "$(dirname "$file")/.tmp.XXXXXX" 2>/dev/null) || die 1 "cannot write in $(dirname "$file")"
  if ! tr -d '\r' <"$file" | WT_RESERVED=$reserved WT_SECTION=$2 WT_CONTENT=$3 awk '
    function emit() {
      print want
      print ""
      printf "%s", content
      if (content != "") print ""
    }
    BEGIN {
      n = split(ENVIRON["WT_RESERVED"], r, "|")
      for (i = 1; i < n; i++) res["## " r[i]] = 1
      want = "## " ENVIRON["WT_SECTION"]
      while ((getline line < ENVIRON["WT_CONTENT"]) > 0) content = content line "\n"
    }
    fm < 2 { print; if ($0 == "---") fm++; next }
    $0 in res {
      skip = 0
      if ($0 == want) { emit(); skip = 1; found = 1; next }
    }
    skip { next }
    { print }
    END { if (!found) emit() }
  ' >"$tmp" 2>/dev/null; then
    rm -f "$tmp"
    die 1 "cannot update $file"
  fi
  mv -f "$tmp" "$file" 2>/dev/null || {
    rm -f "$tmp"
    die 1 "cannot write $file"
  }
}

# emit_section <name> <prepared content file>: a section as new files lay it out.
emit_section() {
  printf '## %s\n\n' "$1"
  if [ -s "$2" ]; then
    cat "$2"
    printf '\n'
  fi
}

# section_append <file> <name> <line>: add one line to the end of a section.
section_append() {
  local content
  new_tmp content
  section_get "$1" "$2" | trim_blank_lines >"$content"
  printf '%s\n' "$3" >>"$content"
  section_set "$1" "$2" "$content"
}

section_is_empty() {
  ! section_get "$1" "$2" | grep -q '[^[:space:]]'
}
