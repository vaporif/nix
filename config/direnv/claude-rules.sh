#!/usr/bin/env bash
# Custom direnv function: use_claude_rules
# Symlinks Claude Code rules from central store into project-local .claude/rules/
#
# Usage in .envrc:
#   use claude_rules           # auto-detect from file extensions
#   use claude_rules go nix    # explicit rule names

CLAUDE_RULES_STORE="${HOME}/.config/claude-rules"

# Auto-detect mappings: extension -> rule name
declare -A _CLAUDE_RULES_MAP=(
  [go]=go
  [rs]=rust
  [lua]=lua
  [nix]=nix
  [sol]=solidity
)

_claude_rules_detect() {
  local detected=()
  local files

  if git rev-parse --is-inside-work-tree &>/dev/null; then
    files=$(git ls-files 2>/dev/null)
  else
    files=$(find . -maxdepth 3 -type f 2>/dev/null)
  fi

  for ext in "${!_CLAUDE_RULES_MAP[@]}"; do
    if echo "${files}" | grep -q "\.${ext}$"; then
      detected+=("${_CLAUDE_RULES_MAP[${ext}]}")
    fi
  done

  printf '%s\n' "${detected[@]}"
}

_claude_rules_link() {
  local name="$1"
  local src="${CLAUDE_RULES_STORE}/${name}.md"
  local dst="${PWD}/.claude/rules/${name}.md"

  if [[ ! -e "${src}" ]]; then
    log_error "claude-rules: ${name}.md not found in ${CLAUDE_RULES_STORE}"
    return
  fi

  ln -sf "${src}" "${dst}"
}

use_claude_rules() {
  local rules_dir="${PWD}/.claude/rules"
  local linked=()

  # Watch central store for changes (re-eval after `just switch`)
  watch_file "${CLAUDE_RULES_STORE}"

  # Remove only symlinks (preserve hand-written project rules)
  if [[ -d "${rules_dir}" ]]; then
    find "${rules_dir}" -maxdepth 1 -type l -delete
  fi

  mkdir -p "${rules_dir}"

  # Determine which rules to link
  local names=()
  if [[ $# -gt 0 ]]; then
    names=("$@")
  else
    while IFS= read -r name; do
      [[ -n "${name}" ]] && names+=("${name}")
    done < <(_claude_rules_detect)
  fi

  # Link each rule
  for name in "${names[@]}"; do
    _claude_rules_link "${name}"
    linked+=("${name}.md")
  done

  if [[ ${#linked[@]} -gt 0 ]]; then
    log_status "claude-rules: linked ${linked[*]}"
  else
    log_status "claude-rules: no rules linked"
  fi
}
