#!/usr/bin/env bash
# Opens tuicr in a tmux split next to the agent and blocks until it exits.
#
#   tuicr-pane -w | -r <revset>           client: run from the repo directory
#   tuicr-pane serve DIR OWNER ROOT PANE  host: started by claude-sandboxed
#
# The sandbox never sees the tmux socket, since anyone who can reach it can
# run-shell outside the sandbox. It only gets DIR, holding a request fifo
# served by a host process that can do this one thing: open `tuicr -w` or
# `tuicr -r <revset>` in a split, in a directory under ROOT.
set -euo pipefail

usage() {
  echo "usage: tuicr-pane -w | -r <revset>" >&2
  exit 2
}

# Only the scopes the tuicr skill uses; a revset is refs and range operators.
validate_args() {
  case "${1:-}" in
    -w) [[ $# -eq 1 ]] ;;
    -r) [[ $# -eq 2 && $2 =~ ^[A-Za-z0-9_./~^@+][A-Za-z0-9_./~^@+-]*$ ]] ;;
    *) return 1 ;;
  esac
}

# Runs on the host: split next to PANE, block until tuicr exits.
open_pane() {
  local dir=$1 pane=$2 chan="tuicr-pane-$$-$RANDOM"
  shift 2
  # argv form: tmux execs this directly, no shell parses the revset.
  # shellcheck disable=SC2016 # $0/$@ belong to the inner bash
  tmux split-window -h -t "$pane" -c "$dir" -- \
    bash -c 'tuicr "$@"; tmux wait-for -S "$0"' "$chan" "$@"
  tmux wait-for "$chan"
}

serve() {
  local dir=$1 owner=$2 root=$3 pane=$4 line resp target
  local -a fields
  exec 3<>"$dir/req"
  # The owner's PID survives its exec into the sandbox, so this ends with it.
  while kill -0 "$owner" 2>/dev/null; do
    IFS= read -r -t 1 line <&3 || continue
    IFS=$'\t' read -r -a fields <<<"$line"
    resp=${fields[0]:-}
    [[ $resp =~ ^resp\.[0-9]+$ && -p "$dir/$resp" ]] || continue
    target=$(realpath -e -- "${fields[1]:-}" 2>/dev/null) || target=
    if [[ -z $target || ($target != "$root" && $target != "$root"/*) ]]; then
      echo "rejected: directory outside $root" 1<>"$dir/$resp"
    elif ! validate_args "${fields[@]:2}"; then
      echo "rejected: only -w or -r <revset>" 1<>"$dir/$resp"
    elif open_pane "$target" "$pane" "${fields[@]:2}"; then
      echo "closed" 1<>"$dir/$resp"
    else
      echo "failed: could not open tmux pane" 1<>"$dir/$resp"
    fi
  done
  rm -rf -- "$dir"
}

if [[ ${1:-} == serve ]]; then
  shift
  serve "$@"
  exit
fi

validate_args "$@" || usage

if [[ -z ${TUICR_BROKER:-} ]]; then
  # Unsandboxed: drive tmux directly.
  [[ -n ${TMUX_PANE:-} ]] || {
    echo "tuicr-pane: not inside tmux, start tuicr yourself" >&2
    exit 1
  }
  open_pane "$PWD" "$TMUX_PANE" "$@"
  echo "closed"
  exit
fi

resp="resp.$$"
mkfifo "$TUICR_BROKER/$resp"
trap 'rm -f "$TUICR_BROKER/$resp"' EXIT
# Held read-write so an instant reply cannot be lost before we read it.
exec 4<>"$TUICR_BROKER/$resp"
(
  IFS=$'\t'
  printf '%s\n' "$resp	$PWD	$*"
) >"$TUICR_BROKER/req"
IFS= read -r status <&4
echo "$status"
[[ $status == closed ]]
