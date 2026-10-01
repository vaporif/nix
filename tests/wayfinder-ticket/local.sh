# Local-backend cases for wayfinder-ticket.

test_usage_unknown_command() {
  assert_exit 2 "$WT" bogus
  assert_contains "$ERR" "unknown command: bogus"
}

test_command_list_matches_dispatcher() {
  local name errf
  [ -n "$WT_COMMANDS" ] || fail "WT_COMMANDS is empty"
  mk_origin
  mk_clone
  errf=$(mktemp)
  for name in $WT_COMMANDS; do
    timeout 10 "$WT" "$name" </dev/null >/dev/null 2>"$errf" || true
    assert_not_contains "$(cat "$errf")" "unknown command:" "$name is not dispatched"
  done
}
