#!/usr/bin/env bash
# Sync shared, unversioned config from .meta/ into every worktree.
# Usage: git meta <init|link|status>
#
# Two classes of entry:
#   - symlinked: .envrc, external/ — one shared copy, linked into each worktree
#   - copied:    docs/specs, docs/plans — real per-worktree dirs; link/init copy
#     them up into .meta per-file, skipping files already there (no overwrite).
#     .meta becomes a no-clobber archive; each worktree keeps its own dir.
#
# Layout (bare repo + sibling worktrees, see git-bare-clone.sh):
#   reponame/
#   ├── .bare/                git dir
#   ├── .meta/                single source of truth (unversioned)
#   │   ├── .files            manifest of symlinked entries, trailing / marks a dir
#   │   ├── .envrc
#   │   ├── docs/{specs,plans}/   archive, populated by copy (no overwrite)
#   │   └── external/
#   └── <worktree>/
#       ├── .envrc     -> ../.meta/.envrc   (symlink)
#       ├── docs/specs                       (real dir, copied up to .meta)
#       └── ...
set -euo pipefail

# Symlinked entries. Directories default where the name has no obvious file
# extension; the manifest's trailing slash is authoritative. .envrc is a file.
SYMLINK_DEFAULTS=(.envrc external/)

# Copied entries: real per-worktree dirs archived up into .meta (no overwrite).
# Hardcoded — these are fixed and must never be symlinked, even if an old
# manifest still lists them.
COPY_ENTRIES=(docs/specs/ docs/plans/)

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
  local bare_dir parent
  bare_dir=$(get_bare_dir)
  parent=$(dirname "${bare_dir}")
  echo "${parent}/.meta"
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
    printf '%s\n' "${SYMLINK_DEFAULTS[@]}"
  fi
}

# True if the entry is a copied (not symlinked) path. Guards against old
# manifests that still list docs/specs or docs/plans.
is_copy_entry() {
  local entry="${1%/}" c
  for c in "${COPY_ENTRIES[@]}"; do
    [[ "${entry}" == "${c%/}" ]] && return 0
  done
  return 1
}

# Iterate symlinked manifest entries, skipping any copy entries.
for_each_symlink() {
  local callback="$1" raw files
  files=$(get_raw_files)
  while IFS= read -r raw; do
    [[ -n "${raw}" ]] || continue
    # shellcheck disable=SC2310 # return 1 is the intended "not a copy entry" signal
    if is_copy_entry "${raw}"; then continue; fi
    "${callback}" "${raw}"
  done <<< "${files}"
}

# Iterate copied entries.
for_each_copy() {
  local callback="$1" raw
  for raw in "${COPY_ENTRIES[@]}"; do
    "${callback}" "${raw}"
  done
}

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
  if [[ "${raw}" == */ ]]; then
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
    local current; current=$(readlink "${dst}")
    [[ "${current}" == "${want}" ]] && { echo "ok:      ${entry}"; return; }
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
    local current; current=$(readlink "${dst}")
    if [[ "${current}" != "${want}" ]]; then
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

# Copy every file under a worktree entry up into .meta, skipping files already
# there (no overwrite). Worktree→meta only; the worktree dir stays real.
copy_entry() {
  local entry="${1%/}"
  local src="${WT_ROOT}/${entry}"
  local dst="${META_DIR}/${entry}"

  if [[ -L "${src}" ]]; then
    warn "${entry} is a symlink (old layout) — rm it to keep a per-worktree copy; skipping"
    return
  fi
  [[ -d "${src}" ]] || { echo "copy:    ${entry} (no dir in worktree)"; return; }

  local f rel target copied=0 kept=0
  # shellcheck disable=SC2312 # find failure yields no files, handled below
  while IFS= read -r -d '' f; do
    rel="${f#"${src}"/}"
    target="${dst}/${rel}"
    if [[ -e "${target}" ]]; then
      kept=$((kept + 1))
    else
      mkdir -p "$(dirname "${target}")"
      cp "${f}" "${target}"
      copied=$((copied + 1))
    fi
  done < <(find "${src}" -type f -print0)

  echo "copy:    ${entry} (${copied} copied, ${kept} kept)"
}

status_copy_entry() {
  local entry="${1%/}"
  local src="${WT_ROOT}/${entry}"
  local dst="${META_DIR}/${entry}"

  if [[ -L "${src}" ]]; then
    echo "diverged: ${entry} (symlink, old layout — rm it for a per-worktree copy)"
    return
  fi
  if [[ ! -d "${src}" ]]; then
    echo "missing:  ${entry} (no dir in worktree)"
    return
  fi

  local f rel pending=0 present=0
  # shellcheck disable=SC2312 # find failure yields no files, handled below
  while IFS= read -r -d '' f; do
    rel="${f#"${src}"/}"
    if [[ -e "${dst}/${rel}" ]]; then
      present=$((present + 1))
    else
      pending=$((pending + 1))
    fi
  done < <(find "${src}" -type f -print0)

  echo "copy:     ${entry} (${pending} to copy, ${present} already in .meta)"
}

# Append managed entries to the shared exclude file so their symlinks and
# per-worktree working dirs don't clutter `git status` in any worktree.
update_exclude() {
  local exclude; exclude="$(get_bare_dir)/info/exclude"
  mkdir -p "$(dirname "${exclude}")"
  touch "${exclude}"
  local raw entry entries
  entries=$(get_raw_files; printf '%s\n' "${COPY_ENTRIES[@]}")
  while IFS= read -r raw; do
    [[ -n "${raw}" ]] || continue
    entry="/${raw%/}"
    grep -qxF "${entry}" "${exclude}" || echo "${entry}" >> "${exclude}"
  done <<< "${entries}"
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
    printf '# (docs/specs, docs/plans are copied, not linked — see git-meta.sh)\n'
    printf '%s\n' "${SYMLINK_DEFAULTS[@]}"
  } > "${META_DIR}/.files"
  echo "created ${META_DIR}/.files"

  # Adopt anything real already in this worktree, then link it back.
  local raw entry src dst_parent raw_files
  raw_files=$(get_raw_files)
  while IFS= read -r raw; do
    [[ -n "${raw}" ]] || continue
    # shellcheck disable=SC2310 # return 1 is the intended "not a copy entry" signal
    if is_copy_entry "${raw}"; then continue; fi
    entry="${raw%/}"
    src="${WT_ROOT}/${entry}"
    if [[ -e "${src}" && ! -L "${src}" ]]; then
      dst_parent=$(dirname "${META_DIR}/${entry}")
      mkdir -p "${dst_parent}"
      mv "${src}" "${META_DIR}/${entry}"
      echo "adopted: ${entry}"
    fi
  done <<< "${raw_files}"

  for_each_symlink link_entry
  for_each_copy copy_entry
  update_exclude
}

cmd_link() {
  require_meta
  for_each_symlink link_entry
  for_each_copy copy_entry
  update_exclude
}

cmd_status() {
  require_meta
  for_each_symlink status_entry
  for_each_copy status_copy_entry
}

case "${1:-}" in
  init)   cmd_init ;;
  link)   cmd_link ;;
  status) cmd_status ;;
  *)      echo "Usage: git meta <init|link|status>" >&2; exit 1 ;;
esac
