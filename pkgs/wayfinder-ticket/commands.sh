MAP_SECTIONS=("Destination" "Decisions so far" "Not yet specified" "Out of scope" "Notes")

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

# yaml_id_list <id>...: a flow list of unique ids in numeric order.
yaml_id_list() {
  local ids
  ids=$(printf '%s\n' "$@" | awk 'NF' | sort -nu | paste -sd, -)
  printf '[%s]\n' "$ids"
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
