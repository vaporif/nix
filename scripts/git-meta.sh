#!/usr/bin/env bash
# Sync non-tracked config files between .meta/ and git worktrees
# Usage: git meta <push|pull|diff|init>
set -euo pipefail

DEFAULTS=(.envrc .serena/ .claude/ CLAUDE.md)

die() { echo "error: $*" >&2; exit 1; }
warn() { echo "warning: $*" >&2; }

get_bare_dir() {
  local common_dir
  common_dir=$(git rev-parse --git-common-dir 2>/dev/null) || die "not in a git repo"
  common_dir=$(cd "${common_dir}" && pwd -P)
  echo "${common_dir}"
}

get_meta_dir() {
  local bare_dir
  bare_dir=$(get_bare_dir)
  echo "$(dirname "${bare_dir}")/.meta"
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

get_files() {
  local meta_dir="$1"
  if [[ -f "${meta_dir}/.files" ]]; then
    grep -v '^\s*#' "${meta_dir}/.files" | grep -v '^\s*$' || true
  else
    printf '%s\n' "${DEFAULTS[@]}"
  fi
}

for_each_file() {
  local callback="$1"
  local files
  files=$(get_files "${META_DIR}")
  while IFS= read -r entry; do
    [[ -n "${entry}" ]] || continue
    "${callback}" "${entry}"
  done <<< "${files}"
}

sync_entry() {
  local src_base="$1" dst_base="$2" entry="${3%/}"
  local src="${src_base}/${entry}" dst="${dst_base}/${entry}"

  if [[ ! -e "${src}" ]]; then
    warn "skipping ${entry} (not found in source)"
    return
  fi

  if [[ -d "${src}" ]]; then
    if [[ -d "${dst}" ]]; then
      rm -rf "${dst}.bak"
      mv "${dst}" "${dst}.bak"
    fi
    mkdir -p "${dst}"
    rsync -a --exclude 'cache/' --exclude 'rules/' --exclude '.bak' "${src}/" "${dst}/"
  else
    if [[ -f "${dst}" ]]; then
      cp -f "${dst}" "${dst}.bak"
    fi
    mkdir -p "$(dirname "${dst}")"
    cp -f "${src}" "${dst}"
  fi
}

diff_entry() {
  local entry="${1%/}"
  local src="${META_DIR}/${entry}" dst="${WT_ROOT}/${entry}"

  if [[ ! -e "${src}" && ! -e "${dst}" ]]; then
    return
  fi
  if [[ ! -e "${src}" ]]; then
    echo "only in worktree: ${entry}"
    return
  fi
  if [[ ! -e "${dst}" ]]; then
    echo "only in .meta: ${entry}"
    return
  fi

  if [[ -d "${src}" ]]; then
    diff -rq --exclude='cache' --exclude='rules' --exclude='.bak' "${src}" "${dst}" 2>/dev/null || true
  else
    diff -u --label ".meta/${entry}" --label "worktree/${entry}" "${src}" "${dst}" 2>/dev/null || true
  fi
}

do_push() {
  local entry="$1"
  echo "push: ${entry}"
  sync_entry "${WT_ROOT}" "${META_DIR}" "${entry}"
}

do_pull() {
  local entry="$1"
  echo "pull: ${entry}"
  sync_entry "${META_DIR}" "${WT_ROOT}" "${entry}"
}

cmd_push() {
  require_meta
  for_each_file do_push
}

cmd_pull() {
  require_meta
  for_each_file do_pull
}

cmd_diff() {
  require_meta
  for_each_file diff_entry
}

cmd_init() {
  assert_worktree
  META_DIR=$(get_meta_dir)
  WT_ROOT=$(get_worktree_root)

  if [[ -d "${META_DIR}" ]]; then
    die ".meta/ already exists at ${META_DIR} (use push/pull to sync)"
  fi

  mkdir -p "${META_DIR}"
  echo "created ${META_DIR}"

  if [[ ! -f "${META_DIR}/.files" ]]; then
    printf '# files to sync between .meta/ and worktrees\n' > "${META_DIR}/.files"
    printf '%s\n' "${DEFAULTS[@]}" >> "${META_DIR}/.files"
    echo "created ${META_DIR}/.files"
  fi

  local files
  files=$(get_files "${META_DIR}")
  while IFS= read -r entry; do
    [[ -n "${entry}" ]] || continue
    if [[ -e "${WT_ROOT}/${entry}" ]]; then
      echo "init: ${entry}"
      sync_entry "${WT_ROOT}" "${META_DIR}" "${entry}"
    fi
  done <<< "${files}"
}

case "${1:-}" in
  push) cmd_push ;;
  pull) cmd_pull ;;
  diff) cmd_diff ;;
  init) cmd_init ;;
  *)    echo "Usage: git meta <push|pull|diff|init>" >&2; exit 1 ;;
esac
