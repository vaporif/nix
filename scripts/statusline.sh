#!/usr/bin/env bash

# Claude Code statusline — cross-platform (macOS + Linux)
# Shows: model+effort, context tokens, vim mode, git branch+diff, worktree, agent
# Line 2: API rate limits (5h/7d) via OAuth usage endpoint

input=$(cat)
OS=$(uname -s)

# --- Earthtone palette (24-bit true color) ---

OLIVE="\033[38;2;96;117;48m"
TOFFEE="\033[38;2;114;89;38m"
BRICK="\033[38;2;162;54;47m"
BRICK_BOLD="\033[1;38;2;162;54;47m"
PLUM="\033[38;2;140;63;101m"
TEAL="\033[38;2;44;118;112m"
DIM="\033[2m"
RESET="\033[0m"

# --- Helpers ---

jq_r() {
  jq -r "$1" <<< "${input}" 2>/dev/null
}

jq_val() {
  jq "$1" <<< "${input}" 2>/dev/null
}

extract_diff_num() {
  local text="$1" keyword="$2"
  case "${OS}" in
    Darwin) echo "${text}" | grep -oE "[0-9]+ ${keyword}" | grep -oE '[0-9]+' || true ;;
    *) echo "${text}" | grep -oP "\d+(?= ${keyword})" || true ;;
  esac
}

# --- Context color based on percentage ---

context_color() {
  local pct=$1
  if [[ "${pct}" -ge 80 ]]; then
    echo "${BRICK_BOLD}"
  elif [[ "${pct}" -ge 60 ]]; then
    echo "${BRICK}"
  elif [[ "${pct}" -ge 50 ]]; then
    echo "${TOFFEE}"
  else
    echo "${OLIVE}"
  fi
}

# --- Model + effort ---

MODEL=$(jq_r '.model.display_name // "Unknown"')

SETTINGS_FILE="${HOME}/.claude/settings.json"
EFFORT=""
if [[ -f "${SETTINGS_FILE}" ]]; then
  EFFORT=$(jq -r '.effortLevel // "high"' "${SETTINGS_FILE}" 2>/dev/null)
fi

case "${EFFORT}" in
  low)  EFFORT_DISPLAY=" ${DIM}low${RESET}" ;;
  medium) EFFORT_DISPLAY=" ${DIM}med${RESET}" ;;
  *) EFFORT_DISPLAY=" ${DIM}high${RESET}" ;;
esac

# --- Context window ---

CONTEXT_SIZE=$(jq_r '.context_window.context_window_size // empty')
USED_PCT=$(jq_r '.context_window.used_percentage // empty')
USAGE=$(jq_val '.context_window.current_usage // null')
EXCEEDS_200K=$(jq_r '.exceeds_200k_tokens // "false"')

if [[ "${USAGE}" != "null" ]] && [[ -n "${USAGE}" ]]; then
  CURRENT=$(echo "${USAGE}" | jq '.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens')
  TOKEN_NUM=$(awk "BEGIN {printf \"%.1f\", ${CURRENT} / 1000}")
  TOKEN_DISPLAY="${TOKEN_NUM}${DIM}k${RESET}"
else
  CURRENT=0
  TOKEN_DISPLAY="0.0${DIM}k${RESET}"
fi

# Use pre-calculated percentage if available, otherwise compute
if [[ -n "${USED_PCT}" ]] && [[ "${USED_PCT}" != "null" ]]; then
  PERCENT="${USED_PCT%%.*}"
elif [[ -n "${CONTEXT_SIZE}" ]] && [[ "${CONTEXT_SIZE}" != "0" ]] && [[ "${CURRENT}" -gt 0 ]]; then
  PERCENT=$((CURRENT * 100 / CONTEXT_SIZE))
else
  PERCENT=0
fi

# Format context limit
CTX_LIMIT_DISPLAY=""
if [[ -n "${CONTEXT_SIZE}" ]] && [[ "${CONTEXT_SIZE}" != "null" ]]; then
  if [[ "${CONTEXT_SIZE}" -ge 1000000 ]]; then
    CTX_LIMIT=$(awk "BEGIN {v=${CONTEXT_SIZE}/1000000; if (v==int(v)) printf \"%d\", v; else printf \"%.1f\", v}")
    CTX_LIMIT_DISPLAY="/${CTX_LIMIT}${DIM}M${RESET}"
  else
    CTX_LIMIT=$(awk "BEGIN {v=${CONTEXT_SIZE}/1000; if (v==int(v)) printf \"%d\", v; else printf \"%.1f\", v}")
    CTX_LIMIT_DISPLAY="/${CTX_LIMIT}${DIM}K${RESET}"
  fi
fi

CTX_COLOR=$(context_color "${PERCENT}")

# 200k warning badge
EXCEED_BADGE=""
if [[ "${EXCEEDS_200K}" = "true" ]]; then
  EXCEED_BADGE=" ${PLUM}!200K${RESET}"
fi

# --- Vim mode ---

VIM_MODE=""
VIM_RAW=$(jq_r '.vim.mode // empty')
if [[ -n "${VIM_RAW}" ]]; then
  VIM_MODE=" | ${TEAL}${VIM_RAW}${RESET}"
fi

# --- Git branch + dirty + diff ---

GIT_BRANCH=""
GIT_DIFF=""

if git rev-parse --git-dir > /dev/null 2>&1; then
  BRANCH=$(git branch --show-current 2>/dev/null)

  if [[ -n "${BRANCH}" ]]; then
    if [[ "${BRANCH}" = "master" ]] || [[ "${BRANCH}" = "main" ]]; then
      BRANCH_COLOR="${BRICK}"
    else
      BRANCH_COLOR="${OLIVE}"
    fi

    # Dirty indicator
    DIRTY=""
    PORCELAIN=$(git status --porcelain 2>/dev/null | head -1 || true)
    if [[ -n "${PORCELAIN}" ]]; then
      DIRTY=" ${TOFFEE}*${RESET}"
    fi

    GIT_BRANCH=" | ${BRANCH_COLOR}${BRANCH}${RESET}${DIRTY}"
  fi

  DIFF_STATS=$(git diff HEAD --shortstat 2>/dev/null)

  if [[ -n "${DIFF_STATS}" ]]; then
    FILES=$(extract_diff_num "${DIFF_STATS}" "file")
    ADDED=$(extract_diff_num "${DIFF_STATS}" "insertion")
    REMOVED=$(extract_diff_num "${DIFF_STATS}" "deletion")

    [[ -z "${FILES}" ]] && FILES="0"
    [[ -z "${ADDED}" ]] && ADDED="0"
    [[ -z "${REMOVED}" ]] && REMOVED="0"

    GIT_DIFF=" ${DIM}${FILES}f${RESET} ${OLIVE}+${ADDED}${RESET} ${BRICK}-${REMOVED}${RESET}"
  fi
fi

# --- Worktree ---

WORKTREE=""
WT_NAME=$(jq_r '.worktree.name // empty')
if [[ -n "${WT_NAME}" ]]; then
  WORKTREE=" | ${TEAL}wt:${WT_NAME}${RESET}"
fi

# --- Agent ---

AGENT=""
AGENT_NAME=$(jq_r '.agent.name // empty')
if [[ -n "${AGENT_NAME}" ]]; then
  AGENT=" | ${PLUM}agent:${AGENT_NAME}${RESET}"
fi

# --- API usage limits (cached, OAuth) ---

USAGE_CACHE="/tmp/claude-usage-cache"
CACHE_MAX_AGE=60
LIMITS_DISPLAY=""

fetch_usage_limits() {
  local token
  case "${OS}" in
    Darwin)
      # macOS: OAuth token stored in Keychain
      local creds
      creds=$(security find-generic-password -s 'Claude Code-credentials' -w 2>/dev/null) || return
      token=$(echo "${creds}" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
      ;;
    *)
      # Linux: OAuth token stored in credentials file
      local creds_file="${HOME}/.claude/.credentials.json"
      [[ -f "${creds_file}" ]] || return
      token=$(jq -r '.claudeAiOauth.accessToken // empty' "${creds_file}" 2>/dev/null)
      ;;
  esac
  [[ -n "${token}" ]] || return
  curl -s --max-time 2 -H "Authorization: Bearer ${token}" \
    -H "anthropic-beta: oauth-2025-04-20" \
    https://api.anthropic.com/api/oauth/usage
}

get_usage_limits() {
  if [[ -f "${USAGE_CACHE}" ]]; then
    local file_mtime cache_age
    case "${OS}" in
      Darwin) file_mtime=$(stat -f %m "${USAGE_CACHE}" 2>/dev/null || echo 0) ;;
      *) file_mtime=$(stat -c %Y "${USAGE_CACHE}" 2>/dev/null || echo 0) ;;
    esac
    cache_age=$(( $(date +%s) - file_mtime ))
    if [[ "${cache_age}" -lt "${CACHE_MAX_AGE}" ]]; then
      cat "${USAGE_CACHE}"
      return
    fi
  fi
  local data
  data=$(fetch_usage_limits)
  if [[ -n "${data}" ]]; then
    echo "${data}" > "${USAGE_CACHE}"
    echo "${data}"
  fi
}

format_time_until() {
  local reset_at="$1"
  [[ -z "${reset_at}" ]] || [[ "${reset_at}" = "null" ]] && return
  local reset_epoch now_epoch diff
  local timestamp="${reset_at%%.*}"  # strip .000Z
  timestamp="${timestamp%Z}"         # strip trailing Z if no millis
  case "${OS}" in
    Darwin) reset_epoch=$(TZ=UTC date -jf "%Y-%m-%dT%H:%M:%S" "${timestamp}" "+%s" 2>/dev/null) ;;
    *) reset_epoch=$(TZ=UTC date -d "${timestamp/T/ }" "+%s" 2>/dev/null) ;;
  esac
  [[ -z "${reset_epoch}" ]] && return
  now_epoch=$(date +%s)
  diff=$((reset_epoch - now_epoch))
  [[ "${diff}" -le 0 ]] && echo "now" && return
  local days=$((diff / 86400)) hours=$(((diff % 86400) / 3600)) mins=$(((diff % 3600) / 60))
  if [[ "${days}" -gt 0 ]]; then
    echo "${days}d${hours}h"
  elif [[ "${hours}" -gt 0 ]]; then
    echo "${hours}h${mins}m"
  else
    echo "${mins}m"
  fi
}

USAGE_LIMITS=$(get_usage_limits)

if [[ -n "${USAGE_LIMITS}" ]]; then
  FIVE_HOUR=$(echo "${USAGE_LIMITS}" | jq -r '.five_hour.utilization // empty' | cut -d. -f1 || true)
  SEVEN_DAY=$(echo "${USAGE_LIMITS}" | jq -r '.seven_day.utilization // empty' | cut -d. -f1 || true)
  FIVE_RESET=$(echo "${USAGE_LIMITS}" | jq -r '.five_hour.resets_at // empty')
  SEVEN_RESET=$(echo "${USAGE_LIMITS}" | jq -r '.seven_day.resets_at // empty')

  if [[ -n "${FIVE_HOUR}" ]] && [[ -n "${SEVEN_DAY}" ]]; then
    FIVE_COLOR=$(context_color "${FIVE_HOUR}")
    SEVEN_COLOR=$(context_color "${SEVEN_DAY}")

    FIVE_TIME=$(format_time_until "${FIVE_RESET}")
    SEVEN_TIME=$(format_time_until "${SEVEN_RESET}")

    FIVE_DISPLAY="${DIM}5h limit${RESET} ${FIVE_COLOR}${FIVE_HOUR}%${RESET}"
    [[ -n "${FIVE_TIME}" ]] && FIVE_DISPLAY="${FIVE_DISPLAY} ${DIM}in${RESET} ${PLUM}${FIVE_TIME}${RESET}"

    SEVEN_DISPLAY="${DIM}weekly${RESET} ${SEVEN_COLOR}${SEVEN_DAY}%${RESET}"
    [[ -n "${SEVEN_TIME}" ]] && SEVEN_DISPLAY="${SEVEN_DISPLAY} ${DIM}in${RESET} ${PLUM}${SEVEN_TIME}${RESET}"

    LIMITS_DISPLAY="${FIVE_DISPLAY} | ${SEVEN_DISPLAY}"
  fi
fi

# --- Output ---

echo -e "[${MODEL}${EFFORT_DISPLAY}] ${CTX_COLOR}${TOKEN_DISPLAY}${RESET}${CTX_LIMIT_DISPLAY} ${DIM}(${CTX_COLOR}${PERCENT}%${RESET}${DIM})${RESET}${EXCEED_BADGE}${VIM_MODE}${GIT_BRANCH}${GIT_DIFF}${WORKTREE}${AGENT}"
if [[ -n "${LIMITS_DISPLAY}" ]]; then
  echo -e "${LIMITS_DISPLAY}"
fi
