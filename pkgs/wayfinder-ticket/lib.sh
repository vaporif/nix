die() {
  local code=$1
  shift
  printf 'wayfinder-ticket: %s\n' "$*" >&2
  exit "$code"
}
