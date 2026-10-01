detect_harness() {
  local found
  case ${WAYFINDER_HARNESS:-} in
  claude | codex)
    printf '%s\n' "$WAYFINDER_HARNESS"
    return
    ;;
  "") ;;
  *) die 1 "WAYFINDER_HARNESS must be claude or codex, not $WAYFINDER_HARNESS" ;;
  esac
  found=$(agent_walk) || die 1 "$NO_AGENT"
  case ${found#* } in
  codex-raw | codex) printf 'codex\n' ;;
  *) printf 'claude\n' ;;
  esac
}

# phase_command <harness> <next> <target>
phase_command() {
  local cmd=$2
  [ "$cmd" = wayfinder ] || [ "$1" = codex ] || cmd=superpowers:$cmd
  if [ "$1" = codex ]; then
    printf '$%s' "$cmd"
  else
    printf '/%s' "$cmd"
  fi
  if [ -n "$3" ]; then
    printf ' %s' "$3"
  fi
  printf '\n'
}

# phase_worktree: the worktree that should run the loaded ticket's next phase:
# the toplevel holding its spec, or with no spec its registered -impl worktree.
phase_worktree() {
  local dir
  if [ -n "$T_SPEC" ]; then
    dir=$(dirname "$T_SPEC")
    [ -d "$dir" ] || return 1
    git -C "$dir" rev-parse --show-toplevel 2>/dev/null
    return
  fi
  find_worktree_by_basename "wayfinder-$SLUG-$ID-impl"
}

local_trailer() {
  local u="trailer <next> [<slug> | <slug>#<id>] [--cd <dir> [--remove <worktree> [--discard]]]"
  [ $# -ge 1 ] || usage_error "$u"
  local next=$1 target="" dir="" remove="" discard=0 harness starter first wt here branch
  shift
  while [ $# -gt 0 ]; do
    case $1 in
    --cd)
      [ $# -ge 2 ] || usage_error "$u"
      dir=$2
      shift 2
      ;;
    --remove)
      [ $# -ge 2 ] || usage_error "$u"
      remove=$2
      shift 2
      ;;
    --discard)
      discard=1
      shift
      ;;
    -*) usage_error "$u" ;;
    *)
      [ -z "$target" ] || usage_error "$u"
      target=$1
      shift
      ;;
    esac
  done
  if { [ -n "$remove" ] && [ -z "$dir" ]; } || { [ "$discard" = 1 ] && [ -z "$remove" ]; }; then
    usage_error "$u"
  fi
  case $next in
  wayfinder)
    [[ $target != *'#'* ]] || die 1 "trailer wayfinder takes a map slug, not a ticket reference: $target"
    if [ -n "$target" ]; then
      check_slug "$target"
    fi
    ;;
  brainstorming | writing-plans | executing-plans)
    [[ $target == *'#'* ]] || die 1 "trailer $next needs a <slug>#<id> reference"
    parse_ref "$target"
    ;;
  *) die 1 "unknown trailer target: $next (expected wayfinder, brainstorming, writing-plans or executing-plans)" ;;
  esac
  harness=$(detect_harness)
  starter=a
  if [ "$harness" = codex ]; then
    starter=o
  fi
  first=/clear
  if [ -n "$dir" ]; then
    first="exit, then run: cd $(printf '%q' "$dir")"
    if [ -n "$remove" ]; then
      need_repo
      branch=$(worktree_branch "$remove") || die 1 "not a registered worktree: $remove"
      wt=$(registered_worktree_path "$remove")
      first+=" && git worktree remove $(printf '%q' "$wt")"
      if [ "$branch" != - ]; then
        first+=" && git branch -$([ "$discard" = 1 ] && printf D || printf d) $(printf '%q' "${branch#refs/heads/}")"
      fi
    fi
    first+=" && $starter"
  elif [ "$next" != wayfinder ]; then
    use_ticket "$target"
    load_ticket "$TICKET_FILE" "$ID"
    if wt=$(phase_worktree) && [ -n "$wt" ]; then
      here=$(git rev-parse --show-toplevel 2>/dev/null) || here=""
      if [ -z "$here" ] || [ "$(realpath "$wt")" != "$(realpath "$here")" ]; then
        first="exit, then run: cd $(printf '%q' "$wt") && $starter"
      fi
    fi
  fi
  printf '%s\n' "$first"
  phase_command "$harness" "$next" "$target"
}
