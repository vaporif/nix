#!/usr/bin/env bash
# Symlink shared, unversioned config from .meta/ into every worktree.
# Usage: git meta <init|link|status>
#
# Layout (bare repo + sibling worktrees, see git-bare-clone.sh):
#   reponame/
#   ├── .bare/                git dir
#   ├── .meta/                single source of truth (unversioned)
#   │   ├── .files            manifest, trailing / marks a directory
#   │   ├── .envrc
#   │   ├── docs/{specs,plans}/
#   │   └── external/
#   └── <worktree>/
#       ├── .envrc     -> ../.meta/.envrc
#       ├── docs/specs -> ../../.meta/docs/specs
#       └── ...
set -euo pipefail

# Entries default to directories where the name has no obvious file extension;
# the manifest's trailing slash is authoritative. .envrc is the lone file.
DEFAULTS=(.envrc docs/specs/ docs/plans/ external/)

die() { echo "error: $*" >&2; exit 1; }
warn() { echo "warning: $*" >&2; }

get_bare_dir() {
  local common_dir
  common_dir=$(git rev-parse --git-common-dir 2>/dev/null) || die "not in a git repo"
  (cd "${common_dir}" && pwd -P)
}

get_meta_dir() {
  # bare_dir is <repo>/.bare, so dirname lands .meta at the project root
  # (<repo>/.meta), scoped per-repo alongside the worktrees.
  echo "$(dirname "$(get_bare_dir)")/.meta"
}

get_worktree_root() {
  git rev-parse --show-toplevel 2>/dev/null || die "not in a worktree"
}

assert_worktree() {
  local git_dir common_dir
  git_dir=$(git rev-parse --git-dir 2>/dev/null) || die "not in a git repo"
  git_dir=$(cd "${git_dir}" && pwd -P)
  common_dir=$(get_bare_dir)
  [[ "${git_dir}" != "${common_dir}" ]] || die "not in a worktree (run from inside a worktree)"
}

require_meta() {
  assert_worktree
  META_DIR=$(get_meta_dir)
  WT_ROOT=$(get_worktree_root)
  [[ -d "${META_DIR}" ]] || die ".meta/ not found at ${META_DIR} (run 'git meta init' first)"
}

# Raw manifest lines (with trailing-slash markers intact) or the defaults.
get_raw_files() {
  if [[ -f "${META_DIR}/.files" ]]; then
    grep -v '^\s*#' "${META_DIR}/.files" | grep -v '^\s*$' || true
  else
    printf '%s\n' "${DEFAULTS[@]}"
  fi
}

is_dir_entry() { [[ "$1" == */ ]]; }

# Relative path from a worktree entry back to .meta/<entry>: one ../ per path
# component, so <wt>/docs/specs -> ../../.meta/docs/specs regardless of nesting.
rel_target() {
  local entry="${1%/}" prefix="" i
  local -a comps
  IFS='/' read -ra comps <<< "${entry}"
  for ((i = 0; i < ${#comps[@]}; i++)); do prefix+="../"; done
  echo "${prefix}.meta/${entry}"
}

# Make sure .meta/<entry> exists so the symlink never dangles.
ensure_meta_target() {
  local raw="$1" entry="${1%/}" target="${META_DIR}/${1%/}"
  [[ -e "${target}" ]] && return
  if is_dir_entry "${raw}"; then
    mkdir -p "${target}"
  else
    mkdir -p "$(dirname "${target}")"
    : > "${target}"
  fi
}

link_entry() {
  local raw="$1" entry="${1%/}"
  local dst="${WT_ROOT}/${entry}"
  local want; want=$(rel_target "${raw}")

  ensure_meta_target "${raw}"

  if [[ -L "${dst}" ]]; then
    [[ "$(readlink "${dst}")" == "${want}" ]] && { echo "ok:      ${entry}"; return; }
    rm "${dst}"
  elif [[ -e "${dst}" ]]; then
    rm -rf "${dst}.bak"
    mv "${dst}" "${dst}.bak"
    warn "backed up real ${entry} -> ${entry}.bak"
  fi

  mkdir -p "$(dirname "${dst}")"
  ln -s "${want}" "${dst}"
  echo "link:    ${entry}"
}

status_entry() {
  local entry="${1%/}"
  local dst="${WT_ROOT}/${entry}"
  local want; want=$(rel_target "$1")

  if [[ -L "${dst}" ]]; then
    if [[ "$(readlink "${dst}")" != "${want}" ]]; then
      echo "diverged: ${entry} (points elsewhere)"
    elif [[ -e "${dst}" ]]; then
      echo "ok:       ${entry}"
    else
      echo "dangling: ${entry} (no target in .meta/)"
    fi
  elif [[ -e "${dst}" ]]; then
    echo "diverged: ${entry} (real file, not a symlink)"
  else
    echo "missing:  ${entry}"
  fi
}

# Append managed entries to the shared exclude file so their symlinks don't
# clutter `git status` in any worktree.
update_exclude() {
  local exclude; exclude="$(get_bare_dir)/info/exclude"
  mkdir -p "$(dirname "${exclude}")"
  touch "${exclude}"
  local raw entry
  while IFS= read -r raw; do
    [[ -n "${raw}" ]] || continue
    entry="/${raw%/}"
    grep -qxF "${entry}" "${exclude}" || echo "${entry}" >> "${exclude}"
  done < <(get_raw_files)
}

for_each() {
  local callback="$1" raw
  while IFS= read -r raw; do
    [[ -n "${raw}" ]] || continue
    "${callback}" "${raw}"
  done < <(get_raw_files)
}

cmd_init() {
  assert_worktree
  META_DIR=$(get_meta_dir)
  WT_ROOT=$(get_worktree_root)

  [[ -d "${META_DIR}" ]] && die ".meta/ already exists at ${META_DIR} (use 'link' to wire up a worktree)"

  mkdir -p "${META_DIR}"
  echo "created ${META_DIR}"

  {
    printf '# files/dirs symlinked from .meta/ into each worktree\n'
    printf '# trailing / marks a directory\n'
    printf '%s\n' "${DEFAULTS[@]}"
  } > "${META_DIR}/.files"
  echo "created ${META_DIR}/.files"

  # Adopt anything real already in this worktree, then link it back.
  local raw entry src
  while IFS= read -r raw; do
    [[ -n "${raw}" ]] || continue
    entry="${raw%/}"
    src="${WT_ROOT}/${entry}"
    if [[ -e "${src}" && ! -L "${src}" ]]; then
      mkdir -p "$(dirname "${META_DIR}/${entry}")"
      mv "${src}" "${META_DIR}/${entry}"
      echo "adopted: ${entry}"
    fi
  done < <(get_raw_files)

  for_each link_entry
  update_exclude
}

cmd_link() {
  require_meta
  for_each link_entry
  update_exclude
}

cmd_status() {
  require_meta
  for_each status_entry
}

case "${1:-}" in
  init)   cmd_init ;;
  link)   cmd_link ;;
  status) cmd_status ;;
  *)      echo "Usage: git meta <init|link|status>" >&2; exit 1 ;;
esac
