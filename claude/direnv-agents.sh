#!/usr/bin/env bash
# Custom direnv function: use_claude_agents
# Symlinks Claude Code agents from the central store into project-local
# .claude/agents/. Agents live outside ~/.claude/agents so they cost nothing in
# sessions for projects that cannot use them — a Nix repo has no reason to load
# the Unity or Solana agent.
#
# Usage in .envrc:
#   use claude_agents                      # auto-detect from project shape
#   use claude_agents rust-engineer        # explicit agent names

CLAUDE_AGENTS_STORE="${HOME}/.config/claude-agents"

# Detection mirrors the project-shape rules in the brainstorming skill: the Rust
# agents are mutually exclusive, so the most specific match wins.
#
# Every probe is depth-bounded and prunes the usual heavy directories. direnvrc
# calls this on entry to every direnv project, so an unbounded tree scan would
# stall the shell in a large monorepo.
_claude_agents_find() {
  find . -maxdepth "$1" \
    \( -name .git -o -name node_modules -o -name target -o -name .direnv \) -prune \
    -o -name "$2" -print 2>/dev/null
}

_claude_agents_detect() {
  local detected=()
  local cargo_tomls=()
  local has_cargo=0

  if [[ -f ProjectSettings/ProjectVersion.txt ]] ||
    { [[ -d Assets ]] && [[ -f Packages/manifest.json ]]; } ||
    [[ -n "$(_claude_agents_find 4 '*.asmdef' | head -n1)" ]]; then
    detected+=(unity-csharp-engineer)
  fi

  mapfile -t cargo_tomls < <(_claude_agents_find 3 Cargo.toml)
  [[ ${#cargo_tomls[@]} -gt 0 ]] && has_cargo=1

  if [[ -f Anchor.toml ]] ||
    { [[ ${has_cargo} -eq 1 ]] && grep -qs '^anchor-lang\b' "${cargo_tomls[@]}"; }; then
    detected+=(solana-developer)
  elif [[ ${has_cargo} -eq 1 ]] && grep -qs '^bevy\b' "${cargo_tomls[@]}"; then
    detected+=(bevy-engineer)
  elif [[ ${has_cargo} -eq 1 ]]; then
    detected+=(rust-engineer)
  fi

  printf '%s\n' "${detected[@]}"
}

_claude_agents_link() {
  local name="$1"
  local src="${CLAUDE_AGENTS_STORE}/${name}.md"
  local dst="${PWD}/.claude/agents/${name}.md"

  if [[ ! -e "${src}" ]]; then
    log_error "claude-agents: ${name}.md not found in ${CLAUDE_AGENTS_STORE}"
    return 1
  fi

  ln -sf "${src}" "${dst}"
}

use_claude_agents() {
  local agents_dir="${PWD}/.claude/agents"
  local linked=()

  # Watch central store for changes (re-eval after `just switch`)
  watch_file "${CLAUDE_AGENTS_STORE}"

  # Remove only symlinks (preserve hand-written project agents)
  if [[ -d "${agents_dir}" ]]; then
    find "${agents_dir}" -maxdepth 1 -type l -delete
  fi

  local names=()
  if [[ $# -gt 0 ]]; then
    names=("$@")
  else
    while IFS= read -r name; do
      [[ -n "${name}" ]] && names+=("${name}")
    done < <(_claude_agents_detect)
  fi

  # Only materialise .claude/agents/ when something will go in it. direnvrc
  # calls this in every project and most match no agent; an empty directory per
  # repo is litter. rmdir also cleans up after an agent stops matching.
  if [[ ${#names[@]} -eq 0 ]]; then
    rmdir "${agents_dir}" 2>/dev/null
    log_status "claude-agents: no agents linked"
    return
  fi

  mkdir -p "${agents_dir}"

  for name in "${names[@]}"; do
    if _claude_agents_link "${name}"; then
      linked+=("${name}.md")
    fi
  done

  if [[ ${#linked[@]} -gt 0 ]]; then
    log_status "claude-agents: linked ${linked[*]}"
  else
    rmdir "${agents_dir}" 2>/dev/null
    log_status "claude-agents: no agents linked"
  fi
}
