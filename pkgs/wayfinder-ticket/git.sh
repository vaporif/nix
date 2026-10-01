FETCHED=0

is_bare_common() {
  [ "$(git --git-dir="$COMMON" rev-parse --is-bare-repository 2>/dev/null)" = true ]
}

ref_exists() {
  git show-ref --verify -q "$1"
}

# default_branch: the bare default branch name (main, never origin/main).
default_branch() {
  local b
  need_repo
  if b=$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null); then
    printf '%s\n' "${b#origin/}"
    return
  fi
  if is_bare_common && b=$(git --git-dir="$COMMON" symbolic-ref -q --short HEAD 2>/dev/null); then
    printf '%s\n' "$b"
    return
  fi
  for b in main master; do
    if ref_exists "refs/heads/$b"; then
      printf '%s\n' "$b"
      return
    fi
  done
  die 1 "cannot determine the default branch"
}

# worktree_records: one "<path>\t<branch or ->\t<bare 0|1>" line per worktree,
# in porcelain order.
worktree_records() {
  git worktree list --porcelain 2>/dev/null | awk '
    function flush() { if (p != "") printf "%s\t%s\t%d\n", p, (b == "" ? "-" : b), bare; p = ""; b = ""; bare = 0 }
    /^worktree / { flush(); p = substr($0, 10); next }
    /^branch / { b = substr($0, 8); next }
    /^bare$/ { bare = 1; next }
    END { flush() }
  '
}

# find_worktree_by_basename <name>: path of the registered worktree with that exact basename.
find_worktree_by_basename() {
  local path branch bare
  while IFS=$'\t' read -r path branch bare; do
    if [ "$bare" = 0 ] && [ "$(basename "$path")" = "$1" ]; then
      printf '%s\n' "$path"
      return 0
    fi
  done < <(worktree_records)
  return 1
}

worktree_branch() {
  local path branch bare want
  want=$(realpath "$1" 2>/dev/null) || return 1
  while IFS=$'\t' read -r path branch bare; do
    if [ "$(realpath "$path" 2>/dev/null)" = "$want" ]; then
      printf '%s\n' "$branch"
      return 0
    fi
  done < <(worktree_records)
  return 1
}

main_root() {
  local def path branch bare first=""
  need_repo
  if ! is_bare_common; then
    git -C "$COMMON/.." rev-parse --show-toplevel 2>/dev/null || die 1 "no main root found"
    return
  fi
  def=$(default_branch 2>/dev/null) || def=""
  while IFS=$'\t' read -r path branch bare; do
    [ "$bare" = 0 ] || continue
    if [ -n "$def" ] && [ "$branch" = "refs/heads/$def" ]; then
      printf '%s\n' "$path"
      return
    fi
    if [ -z "$first" ] && [[ $path != */.claude/worktrees/* ]]; then
      first=$path
    fi
  done < <(worktree_records)
  [ -n "$first" ] || die 1 "no main root found"
  printf '%s\n' "$first"
}

# fetch_default <branch>: one best-effort fetch per run.
fetch_default() {
  [ "$FETCHED" = 0 ] || return 0
  FETCHED=1
  if git remote get-url origin >/dev/null 2>&1; then
    GIT_TERMINAL_PROMPT=0 timeout 30 git fetch -q origin "$1" </dev/null >/dev/null 2>&1 || true
  fi
}

merged_status() {
  local branch=$1 def
  def=$(default_branch)
  if ! ref_exists "refs/heads/$branch"; then
    printf 'unknown\n'
    return
  fi
  if ref_exists "refs/heads/$def" && git merge-base --is-ancestor "refs/heads/$branch" "refs/heads/$def" 2>/dev/null; then
    printf 'merged local\n'
    return
  fi
  fetch_default "$def"
  if ref_exists "refs/remotes/origin/$def" &&
    git merge-base --is-ancestor "refs/heads/$branch" "refs/remotes/origin/$def" 2>/dev/null; then
    printf 'merged origin\n'
    return
  fi
  printf 'unmerged\n'
}

check_branch_name() {
  git check-ref-format --branch "$1" >/dev/null 2>&1 || die 1 "invalid branch name: $1"
}

local_main_root() {
  [ $# -eq 0 ] || usage_error "main-root"
  main_root
}

local_default_branch() {
  [ $# -eq 0 ] || usage_error "default-branch"
  default_branch
}

local_merged() {
  [ $# -eq 1 ] || usage_error "merged <branch>"
  need_repo
  check_branch_name "$1"
  merged_status "$1"
}

local_base_ref() {
  local u="base-ref <slug>#<id> [--stack <branch>]"
  [ $# -ge 1 ] || usage_error "$u"
  local ref=$1 stack="" def local_ref origin_ref
  shift
  while [ $# -gt 0 ]; do
    case $1 in
    --stack)
      [ $# -ge 2 ] || usage_error "$u"
      stack=$2
      shift 2
      ;;
    *) usage_error "$u" ;;
    esac
  done
  use_ticket "$ref"
  load_ticket "$TICKET_FILE" "$ID"
  if [ -n "$stack" ]; then
    check_branch_name "$stack"
    printf '%s\n' "$stack"
    return
  fi
  def=$(default_branch)
  local_ref=refs/heads/$def
  origin_ref=refs/remotes/origin/$def
  fetch_default "$def"
  if ref_exists "$local_ref" && ref_exists "$origin_ref" &&
    [ "$(git rev-parse "$local_ref")" != "$(git rev-parse "$origin_ref")" ] &&
    git merge-base --is-ancestor "$local_ref" "$origin_ref"; then
    printf 'origin/%s\n' "$def"
  elif ref_exists "$local_ref"; then
    printf '%s\n' "$def"
  elif ref_exists "$origin_ref"; then
    printf 'origin/%s\n' "$def"
  else
    die 1 "neither $def nor origin/$def exists"
  fi
}
