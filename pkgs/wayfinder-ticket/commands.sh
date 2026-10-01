MAP_SECTIONS=("Destination" "Decisions so far" "Not yet specified" "Out of scope" "Notes")
REWIRED=()

map_frontmatter() {
  WT_SLUG=$1 WT_TITLE=$2 WT_CREATED=$(date -u +%Y-%m-%dT%H:%M:%SZ) yq -n '
    .slug = strenv(WT_SLUG) |
    .title = strenv(WT_TITLE) |
    .status = "active" |
    .created = strenv(WT_CREATED)'
}

# ticket_document <id> <type> <title> <blocked-by yaml> <question file>
ticket_document() {
  printf -- '---\n'
  WT_ID=$1 WT_TYPE=$2 WT_TITLE=$3 WT_PHASE=$(initial_phase "$2") WT_BLOCKED=$4 yq -n '
    .id = (strenv(WT_ID) | from_yaml) |
    .type = strenv(WT_TYPE) |
    .title = strenv(WT_TITLE) |
    .status = "open" |
    .phase = strenv(WT_PHASE) |
    .["blocked-by"] = (strenv(WT_BLOCKED) | from_yaml) |
    .["blocked-by"] style = "flow" |
    .["claimed-by"] = "" |
    .spec = "" |
    .plan = "" |
    .branch = "" |
    .["superseded-by"] = "" |
    .findings = ""'
  printf -- '---\n\n'
  emit_section Question "$5"
  emit_section Notes /dev/null
}

require_upkeep_allowed() {
  [ "$T_STATUS" = open ] || die 4 "ticket closed: $1"
  if [ -n "$T_CLAIMED" ] && [ "$T_CLAIMED" != "$SID" ] && claim_live "$CLAIM_FILE"; then
    die 6 "claimed by another session ($T_CLAIMED)"
  fi
}

local_map_new() {
  local u="map-new <slug> <title> --destination <file>"
  [ $# -ge 2 ] || usage_error "$u"
  local slug=$1 title=$2 dest="" content target staging
  shift 2
  while [ $# -gt 0 ]; do
    case $1 in
    --destination)
      [ $# -ge 2 ] || usage_error "$u"
      dest=$2
      shift 2
      ;;
    *) usage_error "$u" ;;
    esac
  done
  [ -n "$dest" ] || usage_error "$u"
  check_slug "$slug"
  ticket_title_ok "$title"
  need_repo
  prepare_content content "$dest" map.md
  target=$(map_dir "$slug")
  [ ! -e "$target" ] || die 1 "map exists: $slug"
  mkdir -p "$COMMON/wayfinder" 2>/dev/null || die 1 "cannot create $COMMON/wayfinder"
  staging=$(mktemp -d "$COMMON/wayfinder/.new-XXXXXX" 2>/dev/null) || die 1 "cannot write in $COMMON/wayfinder"
  TMPFILES+=("$staging")
  {
    printf -- '---\n'
    map_frontmatter "$slug" "$title"
    printf -- '---\n\n'
    emit_section Destination "$content"
    emit_section "Decisions so far" /dev/null
    emit_section "Not yet specified" /dev/null
    emit_section "Out of scope" /dev/null
    emit_section Notes /dev/null
  } >"$staging/map.md" || die 1 "cannot write $staging/map.md"
  : >"$staging/map.write"
  # A rename onto an existing map dir fails, so two racing map-new calls cannot both win.
  mv -T "$staging" "$target" 2>/dev/null || die 1 "map exists: $slug"
}

local_maps() {
  [ $# -eq 0 ] || usage_error "maps"
  need_repo
  local d slug open id
  for d in "$COMMON"/wayfinder/*/; do
    slug=$(basename "$d")
    [[ $slug =~ $SLUG_RE ]] || continue
    [ -f "$d/map.md" ] || continue
    MAP_DIR=${d%/}
    load_map "$MAP_DIR/map.md" "$slug"
    open=0
    for id in $(ticket_ids "$MAP_DIR"); do
      load_ticket "$MAP_DIR/$id.md" "$id"
      if [ "$T_STATUS" = open ]; then
        open=$((open + 1))
      fi
    done
    printf '%s\t%s\t%s\n' "$slug" "$M_STATUS" "$open"
  done
}

local_map_edit() {
  local u="map-edit <slug> <section> --file <file> --expect <sha256>"
  [ $# -ge 2 ] || usage_error "$u"
  local slug=$1 section=$2 file="" expect="" have_expect=0 content current
  shift 2
  while [ $# -gt 0 ]; do
    case $1 in
    --file)
      [ $# -ge 2 ] || usage_error "$u"
      file=$2
      shift 2
      ;;
    --expect)
      [ $# -ge 2 ] || usage_error "$u"
      expect=$2
      have_expect=1
      shift 2
      ;;
    *) usage_error "$u" ;;
    esac
  done
  [ -n "$file" ] && [ "$have_expect" = 1 ] || usage_error "$u"
  check_slug "$slug"
  case $section in
  "Decisions so far") die 1 "Decisions so far is append-only; resolve appends to it" ;;
  Destination | "Not yet specified" | "Out of scope" | Notes) ;;
  *) die 1 "unknown section: $section" ;;
  esac
  use_map "$slug"
  prepare_content content "$file" map.md
  lock_map "$slug"
  load_map "$MAP_FILE" "$slug"
  current=$(section_hash "$MAP_FILE" "$section")
  [ "$current" = "$expect" ] || die 1 "$section changed since --expect was read; re-run show-map, merge and retry"
  section_set "$MAP_FILE" "$section" "$content"
}

local_new() {
  local u="new <slug> <type> <title> [--question <file>] [--blocked-by <id>...]"
  [ $# -ge 3 ] || usage_error "$u"
  local slug=$1 type=$2 title=$3 question="" content b max id doc
  local blocked=()
  shift 3
  while [ $# -gt 0 ]; do
    case $1 in
    --question)
      [ $# -ge 2 ] || usage_error "$u"
      question=$2
      shift 2
      ;;
    --blocked-by)
      shift
      [ $# -ge 1 ] && [[ $1 != --* ]] || usage_error "$u"
      while [ $# -gt 0 ] && [[ $1 != --* ]]; do
        blocked+=("$1")
        shift
      done
      ;;
    *) usage_error "$u" ;;
    esac
  done
  check_slug "$slug"
  valid_type "$type" || die 1 "unknown type: $type"
  ticket_title_ok "$title"
  for b in "${blocked[@]}"; do
    check_id "$b"
  done
  use_map "$slug"
  if [ -n "$question" ]; then
    prepare_content content "$question" ticket.md
  else
    new_tmp content
  fi
  lock_map "$slug"
  load_map "$MAP_FILE" "$slug"
  [ "$M_STATUS" = active ] || die 1 "map $slug is complete"
  for b in "${blocked[@]}"; do
    ticket_exists "$b" || die 1 "id $b not in map"
  done
  max=$(ticket_ids "$MAP_DIR" | tail -1)
  id=$((${max:-0} + 1))
  new_tmp doc
  ticket_document "$id" "$type" "$title" "$(yaml_id_list "${blocked[@]}")" "$content" >"$doc"
  : >"$MAP_DIR/$id.claim" 2>/dev/null || die 1 "cannot write $MAP_DIR/$id.claim"
  write_file "$MAP_DIR/$id.md" "$doc"
  printf '%s\n' "$id"
}

local_show() {
  [ $# -eq 1 ] || usage_error "show <slug>#<id>"
  use_ticket "$1"
  load_ticket "$TICKET_FILE" "$ID"
  printf 'path: %s\n' "$TICKET_FILE"
  cat "$TICKET_FILE"
}

local_show_map() {
  [ $# -eq 1 ] || usage_error "show-map <slug>"
  check_slug "$1"
  use_map "$1"
  local snap s
  # Hash the same bytes that are printed, even if a writer renames in between.
  new_tmp snap -d
  cp "$MAP_FILE" "$snap/map.md"
  load_map "$snap/map.md" "$1"
  printf 'path: %s\n' "$MAP_FILE"
  cat "$snap/map.md"
  for s in "${MAP_SECTIONS[@]}"; do
    printf 'section-hash\t%s\t%s\n' "$s" "$(section_hash "$snap/map.md" "$s")"
  done
}

local_edit() {
  local u="edit <slug>#<id> <Question|Notes|Title> --file <file>"
  [ $# -ge 2 ] || usage_error "$u"
  local ref=$1 section=$2 file="" content title
  shift 2
  while [ $# -gt 0 ]; do
    case $1 in
    --file)
      [ $# -ge 2 ] || usage_error "$u"
      file=$2
      shift 2
      ;;
    *) usage_error "$u" ;;
    esac
  done
  [ -n "$file" ] || usage_error "$u"
  parse_ref "$ref"
  case $section in
  Question | Notes | Title) ;;
  *) die 1 "unknown section: $section" ;;
  esac
  use_ticket "$ref"
  prepare_content content "$file" ticket.md
  if [ "$section" = Title ]; then
    title=$(cat "$content")
    ticket_title_ok "$title"
  fi
  lock_map "$SLUG"
  load_ticket "$TICKET_FILE" "$ID"
  require_upkeep_allowed "$ref"
  if [ "$section" = Title ]; then
    fm_set_str "$TICKET_FILE" title "$title"
  else
    section_set "$TICKET_FILE" "$section" "$content"
  fi
}

# remove_proto_worktree <slug> <id>: exact basename match, never a glob, so map
# foo never touches map foo-bar's worktrees and -impl worktrees never match.
remove_proto_worktree() {
  local wt
  wt=$(find_worktree_by_basename "wayfinder-$1-$2") || return 0
  if ! git worktree remove --force "$wt" >/dev/null 2>&1; then
    printf 'wayfinder-ticket: could not remove prototype worktree %s\n' "$wt" >&2
  fi
  git worktree prune >/dev/null 2>&1 || true
}

local_map_complete() {
  [ $# -eq 1 ] || usage_error "map-complete <slug>"
  local slug=$1 id open=()
  check_slug "$slug"
  use_map "$slug"
  lock_map "$slug"
  load_map "$MAP_FILE" "$slug"
  load_graph
  for id in $(ticket_ids "$MAP_DIR"); do
    if [ "${STATUS_OF[$id]}" != closed ]; then
      open+=("$id")
    fi
  done
  [ ${#open[@]} -eq 0 ] || die 1 "open tickets remain: $(IFS=,; printf '%s' "${open[*]}")"
  section_is_empty "$MAP_FILE" "Not yet specified" || die 1 "Not yet specified is not empty"
  if [ "$M_STATUS" != complete ]; then
    fm_set_str "$MAP_FILE" status complete
  fi
  for id in $(ticket_ids "$MAP_DIR"); do
    remove_proto_worktree "$slug" "$id"
  done
}

# edit_blockers <block|unblock> <ref> <id>...
edit_blockers() {
  local mode=$1 ref=$2 b list=()
  shift 2
  [ $# -ge 1 ] || usage_error "$mode <slug>#<id> <id>..."
  parse_ref "$ref"
  for b in "$@"; do
    check_id "$b"
  done
  use_ticket "$ref"
  lock_map "$SLUG"
  load_ticket "$TICKET_FILE" "$ID"
  require_upkeep_allowed "$ref"
  for b in "$@"; do
    ticket_exists "$b" || die 1 "id $b not in map"
  done
  if [ "$mode" = block ]; then
    load_graph
    for b in "$@"; do
      if reaches "$b" "$ID"; then
        die 1 "blocking $ref on $b would create a cycle"
      fi
      GRAPH[$ID]="${GRAPH[$ID]} $b"
    done
    read -ra list <<<"$T_BLOCKED $*"
  else
    for b in $T_BLOCKED; do
      if [[ " $* " != *" $b "* ]]; then
        list+=("$b")
      fi
    done
  fi
  set_blocked "$TICKET_FILE" "${list[@]}"
}

local_block() {
  edit_blockers block "$@"
}

local_unblock() {
  edit_blockers unblock "$@"
}

local_attach() {
  local u="attach <slug>#<id> --findings <file>"
  [ $# -ge 1 ] || usage_error "$u"
  local ref=$1 file=""
  shift
  while [ $# -gt 0 ]; do
    case $1 in
    --findings)
      [ $# -ge 2 ] || usage_error "$u"
      file=$2
      shift 2
      ;;
    *) usage_error "$u" ;;
    esac
  done
  [ -n "$file" ] || usage_error "$u"
  parse_ref "$ref"
  need_repo
  if [ ! -r "$file" ] || [ -d "$file" ]; then
    die 1 "cannot read $file"
  fi
  use_ticket "$ref"
  lock_map "$SLUG"
  load_ticket "$TICKET_FILE" "$ID"
  [ "$T_STATUS" = open ] || die 4 "ticket closed: $ref"
  require_owner "$ref"
  mkdir -p "$MAP_DIR/findings" 2>/dev/null || die 1 "cannot create $MAP_DIR/findings"
  write_file "$MAP_DIR/findings/$ID.md" "$file"
  fm_set_str "$TICKET_FILE" findings "$MAP_DIR/findings/$ID.md"
}

local_advance() {
  local u="advance <slug>#<id> <from> <to> [spec=<path>] [plan=<path>]"
  [ $# -ge 3 ] || usage_error "$u"
  local ref=$1 from=$2 to=$3 expr k
  local -A set=()
  shift 3
  while [ $# -gt 0 ]; do
    case $1 in
    spec=* | plan=*) set[${1%%=*}]=${1#*=} ;;
    *) usage_error "$u" ;;
    esac
    shift
  done
  parse_ref "$ref"
  need_repo
  legal_edge "$from" "$to" || die 1 "illegal phase edge: $from -> $to"
  for k in "${!set[@]}"; do
    [[ ${set[$k]} == /* ]] || die 1 "$k must be an absolute path: ${set[$k]}"
  done
  use_ticket "$ref"
  lock_map "$SLUG"
  load_ticket "$TICKET_FILE" "$ID"
  [ "$T_STATUS" = open ] || die 4 "ticket closed: $ref"
  require_owner "$ref"
  [ "$T_PHASE" = "$from" ] || die 5 "phase is ${T_PHASE:--}, expected $from"
  expr='.phase = strenv(WT_PHASE)'
  if [ -n "${set[spec]+x}" ]; then
    expr+=' | .spec = strenv(WT_SPEC)'
  fi
  if [ -n "${set[plan]+x}" ]; then
    expr+=' | .plan = strenv(WT_PLAN)'
  fi
  WT_PHASE=$to WT_SPEC=${set[spec]:-} WT_PLAN=${set[plan]:-} fm_update "$TICKET_FILE" "$expr"
}

local_resolve() {
  local u="resolve <slug>#<id> --answer <file>"
  [ $# -ge 1 ] || usage_error "$u"
  local ref=$1 file="" answer stage
  shift
  while [ $# -gt 0 ]; do
    case $1 in
    --answer)
      [ $# -ge 2 ] || usage_error "$u"
      file=$2
      shift 2
      ;;
    *) usage_error "$u" ;;
    esac
  done
  [ -n "$file" ] || usage_error "$u"
  parse_ref "$ref"
  need_repo
  use_ticket "$ref"
  prepare_content answer "$file" ticket.md
  lock_map "$SLUG"
  load_map "$MAP_FILE" "$SLUG"
  load_ticket "$TICKET_FILE" "$ID"
  [ "$T_STATUS" = open ] || die 4 "ticket closed: $ref"
  require_owner "$ref"
  [ "$T_TYPE" != implementation ] || die 1 "implementation tickets are closed with close, not resolve"
  if [ "$T_TYPE" = research:options ] && [ "$T_PHASE" != wayfinder:resolve ]; then
    die 5 "phase is ${T_PHASE:--}, expected wayfinder:resolve"
  fi
  release_for_close "$ref"
  stage_copy stage "$TICKET_FILE"
  section_set "$stage" Answer "$answer"
  fm_update "$stage" '.status = "closed" | .["claimed-by"] = ""'
  commit_stage "$stage" "$TICKET_FILE"
  section_append "$MAP_FILE" "Decisions so far" "- $ref: $T_TITLE"
  remove_proto_worktree "$SLUG" "$ID"
}

local_close() {
  local u="close <slug>#<id> --evidence <file> --outcome merge|pr|keep"
  [ $# -ge 1 ] || usage_error "$u"
  local ref=$1 file="" outcome="" evidence branch stage
  shift
  while [ $# -gt 0 ]; do
    case $1 in
    --evidence)
      [ $# -ge 2 ] || usage_error "$u"
      file=$2
      shift 2
      ;;
    --outcome)
      [ $# -ge 2 ] || usage_error "$u"
      outcome=$2
      shift 2
      ;;
    *) usage_error "$u" ;;
    esac
  done
  [ -n "$file" ] || usage_error "$u"
  case $outcome in
  merge | pr | keep) ;;
  *) usage_error "$u" ;;
  esac
  parse_ref "$ref"
  need_repo
  use_ticket "$ref"
  prepare_content evidence "$file" ticket.md
  grep -q '[^[:space:]]' "$evidence" || die 1 "verification evidence is empty"
  lock_map "$SLUG"
  load_ticket "$TICKET_FILE" "$ID"
  [ "$T_STATUS" = open ] || die 4 "ticket closed: $ref"
  require_owner "$ref"
  [ "$T_PHASE" = superpowers:executing-plans ] || die 5 "phase is ${T_PHASE:--}, expected superpowers:executing-plans"
  if [ "$outcome" = merge ]; then
    branch=$(default_branch)
  else
    branch=$(git branch --show-current 2>/dev/null) || branch=""
    [ -n "$branch" ] || die 1 "HEAD is detached; run close from the ticket's branch"
  fi
  release_for_close "$ref"
  stage_copy stage "$TICKET_FILE"
  section_set "$stage" "Verification evidence" "$evidence"
  WT_BRANCH=$branch fm_update "$stage" \
    '.phase = "implemented" | .branch = strenv(WT_BRANCH) | .status = "closed" | .["claimed-by"] = ""'
  commit_stage "$stage" "$TICKET_FILE"
}

# supersede_rewire <new id>: point every open dependent of ID at <new id> in
# GRAPH, setting REWIRED; rejects the drop if that would create a cycle.
supersede_rewire() {
  local sup=$1 d b list
  REWIRED=()
  load_graph
  for d in $(ticket_ids "$MAP_DIR"); do
    if [ "$d" = "$ID" ] || [ "${STATUS_OF[$d]}" != open ] || [[ " ${GRAPH[$d]} " != *" $ID "* ]]; then
      continue
    fi
    list=()
    for b in ${GRAPH[$d]}; do
      if [ "$b" = "$ID" ]; then
        list+=("$sup")
      else
        list+=("$b")
      fi
    done
    GRAPH[$d]="${list[*]}"
    REWIRED+=("$d")
  done
  for d in "${REWIRED[@]}"; do
    if reaches "$sup" "$d"; then
      die 1 "superseding $SLUG#$ID with $SLUG#$sup would create a cycle through $SLUG#$d"
    fi
  done
}

local_drop() {
  local u="drop <slug>#<id> --reason <text> [--superseded-by <id>]"
  [ $# -ge 1 ] || usage_error "$u"
  local ref=$1 reason="" sup="" raw answer stage d list
  REWIRED=()
  shift
  while [ $# -gt 0 ]; do
    case $1 in
    --reason)
      [ $# -ge 2 ] || usage_error "$u"
      reason=$2
      shift 2
      ;;
    --superseded-by)
      [ $# -ge 2 ] || usage_error "$u"
      sup=$2
      shift 2
      ;;
    *) usage_error "$u" ;;
    esac
  done
  [ -n "$reason" ] || usage_error "$u"
  parse_ref "$ref"
  if [ -n "$sup" ]; then
    check_id "$sup"
  fi
  need_repo
  use_ticket "$ref"
  new_tmp raw
  if [ -n "$sup" ]; then
    printf 'Superseded by %s#%s: %s\n' "$SLUG" "$sup" "$reason" >"$raw"
  else
    printf 'Dropped: %s\n' "$reason" >"$raw"
  fi
  prepare_content answer "$raw" ticket.md
  lock_map "$SLUG"
  load_map "$MAP_FILE" "$SLUG"
  load_ticket "$TICKET_FILE" "$ID"
  require_upkeep_allowed "$ref"
  if [ -n "$sup" ]; then
    [ "$sup" != "$ID" ] || die 1 "$ref cannot be superseded by itself"
    ticket_exists "$sup" || die 1 "id $sup not in map"
    supersede_rewire "$sup"
  fi
  release_for_close "$ref"
  stage_copy stage "$TICKET_FILE"
  section_set "$stage" Answer "$answer"
  WT_SUP=${sup:-'""'} fm_update "$stage" \
    '.status = "closed" | .["claimed-by"] = "" | .["superseded-by"] = (strenv(WT_SUP) | from_yaml)'
  commit_stage "$stage" "$TICKET_FILE"
  for d in "${REWIRED[@]}"; do
    read -ra list <<<"${GRAPH[$d]}"
    set_blocked "$MAP_DIR/$d.md" "${list[@]}"
  done
  if [ -z "$sup" ]; then
    section_append "$MAP_FILE" "Out of scope" "- $ref $T_TITLE: ${reason//$'\n'/ }"
  fi
  remove_proto_worktree "$SLUG" "$ID"
}
