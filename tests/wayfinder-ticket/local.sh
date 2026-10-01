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

# --- Stage A: references, maps, tickets, sections ---

# Prints the bytes of one body section from show/show-map output.
section_of() {
  awk -v want="## $2" -v kind="$3" '
    BEGIN {
      if (kind == "map") n = split("Destination|Decisions so far|Not yet specified|Out of scope|Notes", r, "|")
      else n = split("Question|Notes|Answer|Verification evidence", r, "|")
      for (i = 1; i <= n; i++) res["## " r[i]] = 1
    }
    NR == 1 { next }
    fm < 2 { if ($0 == "---") fm++; next }
    /^section-hash\t/ { exit }
    $0 in res { on = ($0 == want); next }
    on { print }
  ' <<<"$1"
}

hash_line() {
  printf '%s\n' "$1" | awk -F'\t' -v s="$2" '$1 == "section-hash" && $2 == s { print $3 }'
}

fm_of() {
  yq --front-matter=extract "$2" "$1"
}

test_ref_rejects_bad_slug() {
  local s outside
  outside=$PWD
  mk_origin
  mk_clone
  mk_map foo >/dev/null
  for s in '../x' 'A' '-x' 'x/y'; do
    assert_exit 1 "$WT" show "$s#1"
    assert_contains "$ERR" "invalid slug"
    assert_exit 1 "$WT" show-map "$s"
    assert_contains "$ERR" "invalid slug"
    assert_exit 1 "$WT" map-new "$s" title --destination "$(text_file d)"
    assert_contains "$ERR" "invalid slug"
    assert_exit 1 "$WT" new "$s" task title
    assert_contains "$ERR" "invalid slug"
    (
      cd "$outside"
      export GIT_CEILING_DIRECTORIES=$outside
      assert_exit 1 "$WT" show "$s#1"
      assert_contains "$ERR" "invalid slug"
    )
  done
  assert_eq "$(ls "$(map_path '')")" "foo" "only the valid map exists"
}

test_ref_rejects_bad_id() {
  local id
  mk_origin
  mk_clone
  mk_map foo >/dev/null
  mk_ticket foo task >/dev/null
  for id in 0 01 1a; do
    assert_exit 1 "$WT" show "foo#$id"
    assert_contains "$ERR" "invalid id"
    assert_exit 1 "$WT" new foo task title --blocked-by "$id"
    assert_contains "$ERR" "invalid id"
  done
  assert_exit 1 "$WT" show foo
  assert_contains "$ERR" "invalid reference"
}

test_map_new_and_maps() {
  local dir
  mk_origin
  mk_clone
  assert_exit 0 "$WT" maps
  assert_eq "$OUT" ""
  assert_exit 0 "$WT" map-new foo "Foo map" --destination "$(text_file "Ship offline sync")"
  assert_eq "$OUT" "" "map-new prints nothing"
  mk_map bar >/dev/null
  dir=$(map_path foo)
  [ -f "$dir/map.md" ] || fail "map.md missing"
  assert_eq "$(realpath "$dir")" "$(realpath "$(git rev-parse --git-common-dir)")/wayfinder/foo"
  assert_eq "$(fm_of "$dir/map.md" .slug)" foo
  assert_eq "$(fm_of "$dir/map.md" .title)" "Foo map"
  assert_eq "$(fm_of "$dir/map.md" .status)" active
  [ -n "$(fm_of "$dir/map.md" .created)" ] || fail "created is empty"
  assert_eq "$(section_of "$("$WT" show-map foo)" Destination map | tr -s '\n')" $'\nShip offline sync' "destination text"
  mk_ticket foo task >/dev/null
  mk_ticket foo task >/dev/null
  assert_exit 0 "$WT" maps
  assert_eq "$OUT" $'bar\tactive\t0\nfoo\tactive\t2'
}

test_map_new_rejects_existing() {
  mk_origin
  mk_clone
  mk_map foo >/dev/null
  assert_unchanged "$(map_path foo)" assert_exit 1 "$WT" map-new foo other --destination "$(text_file d)"
  assert_contains "$ERR" "foo"
}

test_new_assigns_next_id_and_initial_phase() {
  local spec type phase id f want=0
  mk_origin
  mk_clone
  mk_map foo >/dev/null
  for spec in 'research:fact|' 'research:options|research' 'grilling|' 'prototype|' 'task|' 'implementation|superpowers:brainstorming'; do
    type=${spec%%|*}
    phase=${spec#*|}
    want=$((want + 1))
    assert_exit 0 "$WT" new foo "$type" "A $type ticket"
    id=$OUT
    assert_eq "$id" "$want" "id for $type"
    f=$(map_path foo)/$id.md
    assert_eq "$(fm_of "$f" .type)" "$type"
    assert_eq "$(fm_of "$f" .phase)" "$phase" "phase for $type"
    assert_eq "$(fm_of "$f" .status)" open
    assert_eq "$(fm_of "$f" '.["claimed-by"]')" ""
    assert_eq "$(fm_of "$f" '.["blocked-by"] | length')" 0
    [ -f "$(map_path foo)/$id.claim" ] || fail "$id.claim missing"
  done
}

test_new_rejects_unknown_type() {
  mk_origin
  mk_clone
  mk_map foo >/dev/null
  assert_unchanged "$(map_path foo)" assert_exit 1 "$WT" new foo bogus title
  assert_contains "$ERR" "unknown type: bogus"
  assert_exit 3 "$WT" new nope task title
  assert_contains "$ERR" "not found: nope"
}

test_new_blocked_by_atomic() {
  mk_origin
  mk_clone
  mk_map foo >/dev/null
  mk_ticket foo task >/dev/null
  mk_ticket foo task >/dev/null
  assert_exit 0 "$WT" new foo task blocked --blocked-by 1 2
  assert_eq "$(fm_of "$(map_path foo)/$OUT.md" '.["blocked-by"] | @json')" "[1,2]"
  assert_exit 0 "$WT" new foo task blocked --blocked-by 1 --blocked-by 2
  assert_eq "$(fm_of "$(map_path foo)/$OUT.md" '.["blocked-by"] | @json')" "[1,2]"
  assert_unchanged "$(map_path foo)" assert_exit 1 "$WT" new foo task blocked --blocked-by 1 9
  assert_contains "$ERR" "id 9 not in map"
}

test_show_and_show_map_hashes() {
  local out want s
  mk_origin
  mk_clone
  mk_map foo >/dev/null
  mk_ticket foo task --question "$(text_file "What now?")" >/dev/null
  assert_exit 0 "$WT" show foo#1
  assert_eq "$(head -1 <<<"$OUT")" "path: $(map_path foo)/1.md"
  assert_eq "$(tail -n +2 <<<"$OUT")" "$(cat "$(map_path foo)/1.md")"
  assert_contains "$(section_of "$OUT" Question ticket)" "What now?"
  assert_exit 0 "$WT" show-map foo
  out=$OUT
  assert_eq "$(head -1 <<<"$out")" "path: $(map_path foo)/map.md"
  assert_eq "$(grep -c $'^section-hash\t' <<<"$out")" 5
  assert_eq "$(grep $'^section-hash\t' <<<"$out" | cut -f2 | paste -sd'|' -)" "Destination|Decisions so far|Not yet specified|Out of scope|Notes"
  for s in "Destination" "Decisions so far" "Not yet specified" "Out of scope" "Notes"; do
    want=$(section_of "$out" "$s" map | sha256sum | cut -d' ' -f1)
    assert_eq "$(hash_line "$out" "$s")" "$want" "hash of $s"
  done
  assert_exit 3 "$WT" show foo#9
  assert_contains "$ERR" "not found: foo#9"
  assert_exit 3 "$WT" show-map nope
  assert_contains "$ERR" "not found: nope"
}

test_map_edit_expect() {
  local dir h new
  mk_origin
  mk_clone
  mk_map foo >/dev/null
  dir=$(map_path foo)
  h=$(hash_line "$("$WT" show-map foo)" Notes)
  assert_exit 0 "$WT" map-edit foo Notes --file "$(text_file "first note")" --expect "$h"
  assert_contains "$(section_of "$("$WT" show-map foo)" Notes map)" "first note"
  new=$(hash_line "$("$WT" show-map foo)" Notes)
  [ "$new" != "$h" ] || fail "Notes hash did not change"
  assert_unchanged "$dir" assert_exit 1 "$WT" map-edit foo Notes --file "$(text_file "second")" --expect "$h"
  assert_contains "$ERR" "Notes"
  assert_unchanged "$dir" assert_exit 2 "$WT" map-edit foo Notes --file "$(text_file "second")"
  h=$(hash_line "$("$WT" show-map foo)" "Decisions so far")
  assert_unchanged "$dir" assert_exit 1 "$WT" map-edit foo "Decisions so far" --file "$(text_file "x")" --expect "$h"
  assert_unchanged "$dir" assert_exit 1 "$WT" map-edit foo Bogus --file "$(text_file "x")" --expect "$h"
  assert_contains "$ERR" "unknown section: Bogus"
  h=$(hash_line "$("$WT" show-map foo)" "Not yet specified")
  assert_exit 0 "$WT" map-edit foo "Not yet specified" --file "$(text_file "- offline conflicts")" --expect "$h"
  assert_contains "$(section_of "$("$WT" show-map foo)" "Not yet specified" map)" "- offline conflicts"
  assert_contains "$(section_of "$("$WT" show-map foo)" Notes map)" "first note"
}

test_edit_sections_and_title() {
  local f
  mk_origin
  mk_clone
  mk_map foo >/dev/null
  mk_ticket foo task --question "$(text_file "old question")" >/dev/null
  f=$(map_path foo)/1.md
  assert_exit 0 "$WT" edit foo#1 Question --file "$(text_file "new question")"
  assert_eq "$(section_of "$("$WT" show foo#1)" Question ticket | tr -s '\n')" $'\nnew question'
  assert_exit 0 "$WT" edit foo#1 Notes --file "$(text_file "a note")"
  assert_eq "$(section_of "$("$WT" show foo#1)" Notes ticket | tr -s '\n')" $'\na note'
  assert_eq "$(section_of "$("$WT" show foo#1)" Question ticket | tr -s '\n')" $'\nnew question'
  assert_exit 0 "$WT" edit foo#1 Title --file "$(text_file "Renamed ticket")"
  assert_eq "$(fm_of "$f" .title)" "Renamed ticket"
  assert_unchanged "$(map_path foo)" assert_exit 1 "$WT" edit foo#1 Title --file "$(text_file $'two\nlines')"
  assert_unchanged "$(map_path foo)" assert_exit 1 "$WT" edit foo#1 Answer --file "$(text_file x)"
  assert_contains "$ERR" "unknown section: Answer"
  assert_exit 3 "$WT" edit foo#7 Notes --file "$(text_file x)"
}

test_malformed_frontmatter_rejected() {
  local dir r
  mk_origin
  mk_clone
  mk_map foo >/dev/null
  mk_ticket foo task >/dev/null
  mk_ticket foo task >/dev/null
  mk_ticket foo task >/dev/null
  dir=$(map_path foo)
  printf -- '---\nid: 1\ntitle: [unclosed\n---\n\n## Question\n' >"$dir/1.md"
  printf 'no frontmatter at all\n' >"$dir/2.md"
  sed -i.bak 's/^id: 3$/id: 4/' "$dir/3.md"
  rm -f "$dir/3.md.bak"
  for r in foo#1 foo#2 foo#3; do
    assert_unchanged "$dir" assert_exit 1 "$WT" show "$r"
    assert_contains "$ERR" "malformed"
    assert_unchanged "$dir" assert_exit 1 "$WT" edit "$r" Notes --file "$(text_file x)"
    assert_contains "$ERR" "malformed"
  done
  printf -- '---\nslug: foo\nstatus: [\n---\n' >"$dir/map.md"
  assert_unchanged "$dir" assert_exit 1 "$WT" show-map foo
  assert_contains "$ERR" "malformed"
  assert_unchanged "$dir" assert_exit 1 "$WT" new foo task title
  assert_contains "$ERR" "malformed"
}

test_title_yaml_special_chars() {
  local t id f
  mk_origin
  mk_clone
  assert_exit 0 "$WT" map-new foo 'Map: "offline" #1 – ü' --destination "$(text_file d)"
  assert_eq "$(fm_of "$(map_path foo)/map.md" .title)" 'Map: "offline" #1 – ü'
  for t in 'Fix: sync #2 – retry' "\"double\" and 'single'" '- leading dash' 'ünïcødé ✓ 日本' 'key: value # comment' \
    '[not, a list]' '{a: b}' 'yes' '123' '~' '@at' '`tick`' 'back\slash' '*star' '&anchor' '!tag' '%pct' '| pipe' '> gt' '  padded  '; do
    assert_exit 0 "$WT" new foo task "$t"
    id=$OUT
    f=$(map_path foo)/$id.md
    assert_eq "$(fm_of "$f" .title)" "$t" "title round trip"
    assert_eq "$(fm_of "$f" '.title | tag')" '!!str' "title is a string"
    assert_eq "$(fm_of "$f" .id)" "$id"
    assert_exit 0 "$WT" edit "foo#$id" Title --file "$(text_file "$t!")"
    assert_eq "$(fm_of "$f" .title)" "$t!" "edited title round trip"
  done
  assert_unchanged "$(map_path foo)" assert_exit 1 "$WT" new foo task $'two\nlines'
  assert_unchanged "$(map_path foo)" assert_exit 1 "$WT" new foo task ''
}

test_from_subdir_and_linked_worktree() {
  local main want
  mk_origin
  mk_clone
  main=$PWD
  mk_map foo >/dev/null
  mk_ticket foo task >/dev/null
  want=$(realpath "$(map_path foo)")
  mkdir -p src/lib
  (
    cd src/lib
    assert_exit 0 "$WT" show foo#1
    assert_eq "$(realpath "$(dirname "$(head -1 <<<"$OUT" | sed 's/^path: //')")")" "$want"
  )
  git worktree add -q .claude/worktrees/wt -b wt
  mkdir -p .claude/worktrees/wt/src/lib
  cd .claude/worktrees/wt/src/lib
  assert_exit 0 "$WT" new foo task "from a linked worktree"
  assert_eq "$OUT" 2
  [ -f "$want/2.md" ] || fail "ticket not in the shared map dir"
  assert_exit 0 "$WT" maps
  assert_eq "$OUT" $'foo\tactive\t2'
  cd "$main/.."
  mk_bclone
  mk_map bar >/dev/null
  git worktree add -q ../other -b other
  mkdir -p ../other/src
  cd ../other/src
  assert_exit 0 "$WT" maps
  assert_eq "$OUT" $'bar\tactive\t0'
  assert_exit 0 "$WT" show-map bar
  assert_eq "$(realpath "$(dirname "$(head -1 <<<"$OUT" | sed 's/^path: //')")")" "$(realpath "$(git rev-parse --git-common-dir)")/wayfinder/bar"
}

test_outside_repo() {
  local cmd
  mkdir outside
  cd outside
  export GIT_CEILING_DIRECTORIES=$PWD/..
  for cmd in "maps" "show foo#1" "show-map foo" "new foo task title" "edit foo#1 Notes --file /dev/null" \
    "main-root" "default-branch" "merged main" "base-ref foo#1" "claim foo#1" "release foo#1" \
    "map-complete foo" "block foo#1 2" "unblock foo#1 2" "attach foo#1 --findings /dev/null" "advance foo#1 a b" \
    "resolve foo#1 --answer /dev/null" "close foo#1 --evidence /dev/null --outcome keep" "drop foo#1 --reason x"; do
    # shellcheck disable=SC2086
    assert_exit 1 "$WT" $cmd
    assert_contains "$ERR" "not inside a git repository"
    assert_not_contains "$ERR" "fatal:"
  done
  assert_exit 1 "$WT" map-new foo title --destination "$(text_file d)"
  assert_contains "$ERR" "not inside a git repository"
}

test_concurrent_new_unique_ids() {
  local i pids=() rc=0
  mk_origin
  mk_clone
  mk_map foo >/dev/null
  for i in $(seq 20); do
    "$WT" new foo task "concurrent $i" >"../out.$i" 2>"../err.$i" &
    pids+=($!)
  done
  for i in "${pids[@]}"; do
    wait "$i" || rc=1
  done
  [ "$rc" = 0 ] || fail "a concurrent new failed: $(cat ../err.*)"
  assert_eq "$(cat ../out.* | sort -n | paste -sd' ' -)" "$(seq 20 | paste -sd' ' -)"
  assert_eq "$(find "$(map_path foo)" -name '[1-9]*.md' | wc -l | tr -d ' ')" 20
}

test_section_text_with_h2_roundtrips() {
  local before after s h f q
  mk_origin
  mk_clone
  mk_map foo >/dev/null
  f=$(text_file $'## Option A\nkeep it simple\n## Option B')
  before=$("$WT" show-map foo)
  h=$(hash_line "$before" Notes)
  assert_exit 0 "$WT" map-edit foo Notes --file "$f" --expect "$h"
  after=$("$WT" show-map foo)
  assert_contains "$(section_of "$after" Notes map)" $'## Option A\nkeep it simple\n## Option B'
  for s in "Destination" "Decisions so far" "Not yet specified" "Out of scope"; do
    assert_eq "$(hash_line "$after" "$s")" "$(hash_line "$before" "$s")" "hash of $s"
  done
  h=$(hash_line "$after" Notes)
  assert_exit 0 "$WT" map-edit foo Notes --file "$(text_file "replaced")" --expect "$h"
  assert_not_contains "$("$WT" show-map foo)" "Option A"
  mk_ticket foo task --question "$(text_file "the question")" >/dev/null
  q=$(section_of "$("$WT" show foo#1)" Question ticket)
  assert_exit 0 "$WT" edit foo#1 Notes --file "$f"
  assert_contains "$("$WT" show foo#1)" $'## Notes\n\n## Option A'
  assert_eq "$(section_of "$("$WT" show foo#1)" Question ticket)" "$q" "Question unchanged"
  assert_contains "$(section_of "$("$WT" show foo#1)" Notes ticket)" "## Option B"
}

test_section_text_rejects_reserved_heading() {
  local f h dir
  mk_origin
  mk_clone
  mk_map foo >/dev/null
  mk_ticket foo task >/dev/null
  dir=$(map_path foo)
  f=$(text_file $'intro\n## Notes\noutro')
  h=$(hash_line "$("$WT" show-map foo)" Destination)
  assert_unchanged "$dir" assert_exit 1 "$WT" map-edit foo Destination --file "$f" --expect "$h"
  assert_contains "$ERR" "content contains section heading: ## Notes"
  assert_unchanged "$dir" assert_exit 1 "$WT" edit foo#1 Question --file "$f"
  assert_contains "$ERR" "content contains section heading: ## Notes"
  assert_unchanged "$dir" assert_exit 1 "$WT" new foo task title --question "$f"
  assert_contains "$ERR" "content contains section heading: ## Notes"
  [ ! -e "$dir/2.md" ] || fail "new created a ticket"
  assert_exit 1 "$WT" map-new bar title --destination "$f"
  assert_contains "$ERR" "content contains section heading: ## Notes"
  [ ! -e "$(map_path bar)" ] || fail "map-new created a map"
  assert_exit 1 "$WT" map-new bar title --destination "$(text_file '## Decisions so far')"
  [ ! -e "$(map_path bar)" ] || fail "map-new created a map"
}

test_section_crlf_normalised() {
  local dir lf crlf h
  mk_origin
  mk_clone
  mk_map foo >/dev/null
  dir=$(map_path foo)
  h=$(hash_line "$("$WT" show-map foo)" Notes)
  "$WT" map-edit foo Notes --file "$(text_file $'line one\nline two')" --expect "$h"
  lf=$("$WT" show-map foo | grep $'^section-hash\t')
  sed 's/$/\r/' "$dir/map.md" >"$dir/map.crlf"
  mv "$dir/map.crlf" "$dir/map.md"
  grep -q $'\r' "$dir/map.md" || fail "fixture has no CR"
  crlf=$("$WT" show-map foo | grep $'^section-hash\t')
  assert_eq "$crlf" "$lf" "hashes after CRLF rewrite"
  h=$(hash_line "$crlf" Notes)
  assert_exit 0 "$WT" map-edit foo Notes --file "$(text_file $'crlf\r\ninput\r')" --expect "$h"
  if grep -q $'\r' "$dir/map.md"; then fail "map.md still has CR"; fi
  assert_contains "$(section_of "$("$WT" show-map foo)" Notes map)" $'crlf\ninput'
}

# --- Stage B: git helpers ---

# commit_on <branch> <file>: a commit on a new branch from HEAD, then back.
commit_on() {
  local back
  back=$(git branch --show-current)
  git switch -q -c "$1"
  echo "$2" >"$2"
  git add "$2"
  git commit -qm "$2"
  git switch -q "$back"
}

# push_origin_commit <file>: lands a commit on origin's main from a scratch clone.
push_origin_commit() {
  local scratch
  scratch=$(mktemp -d)
  git clone -q "$(git remote get-url origin)" "$scratch/c"
  echo "$1" >"$scratch/c/$1"
  git -C "$scratch/c" add "$1"
  git -C "$scratch/c" commit -qm "$1"
  git -C "$scratch/c" push -q origin main
  rm -rf "$scratch"
}

# First non-bare worktree in porcelain order.
first_listed_worktree() {
  git worktree list --porcelain | awk '
    /^worktree / { p = substr($0, 10); bare = 0; next }
    /^bare$/ { bare = 1; next }
    /^$/ { if (p != "" && !bare) { print p; exit } p = "" }
  '
}

test_main_root_normal_clone() {
  local root
  mk_origin
  mk_clone
  root=$(realpath "$PWD")
  assert_exit 0 "$WT" main-root
  assert_eq "$(realpath "$OUT")" "$root"
  mkdir -p src/lib
  cd src/lib
  assert_exit 0 "$WT" main-root
  assert_eq "$(realpath "$OUT")" "$root"
}

test_main_root_from_nested_claude_worktree() {
  local root
  mk_origin
  mk_clone
  root=$(realpath "$PWD")
  git worktree add -q .claude/worktrees/a -b a
  cd .claude/worktrees/a
  assert_exit 0 "$WT" main-root
  assert_eq "$(realpath "$OUT")" "$root"
  git worktree add -q .claude/worktrees/b -b b
  mkdir -p .claude/worktrees/b/sub
  cd .claude/worktrees/b/sub
  assert_exit 0 "$WT" main-root
  assert_eq "$(realpath "$OUT")" "$root"
}

test_main_root_bclone_default_worktree() {
  local root
  mk_origin
  mk_bclone
  root=$(realpath "$PWD")
  assert_exit 0 "$WT" main-root
  assert_eq "$(realpath "$OUT")" "$root"
  git worktree add -q .claude/worktrees/t -b t
  cd .claude/worktrees/t
  assert_exit 0 "$WT" main-root
  assert_eq "$(realpath "$OUT")" "$root"
}

test_main_root_bclone_main_switched_away() {
  local root
  mk_origin
  mk_bclone
  root=$(realpath "$PWD")
  # Under the bclone root, so it is listed before main/.
  git worktree add -q ../.claude/worktrees/aa -b aa
  git switch -q -c other
  assert_eq "$(realpath "$(first_listed_worktree)")" "$(realpath ../.claude/worktrees/aa)" "a .claude worktree is listed first"
  cd ../.claude/worktrees/aa
  assert_exit 0 "$WT" main-root
  assert_eq "$(realpath "$OUT")" "$root"
}

test_main_root_bclone_origin_head_after_fetch() {
  local root
  mk_origin
  mk_bclone
  root=$(realpath "$PWD")
  git fetch -q origin
  git remote set-head origin main
  git symbolic-ref -q refs/remotes/origin/HEAD >/dev/null || fail "origin/HEAD not set"
  git worktree add -q .claude/worktrees/t -b t
  cd .claude/worktrees/t
  assert_exit 0 "$WT" main-root
  assert_eq "$(realpath "$OUT")" "$root"
}

test_main_root_bclone_wb_sibling_listed_first() {
  local root
  mk_origin
  mk_bclone
  root=$(realpath "$PWD")
  git worktree add -q ../0-sibling -b 0-sibling
  assert_eq "$(realpath "$(first_listed_worktree)")" "$(realpath ../0-sibling)" "the sibling is listed first"
  cd ../0-sibling
  assert_exit 0 "$WT" main-root
  assert_eq "$(realpath "$OUT")" "$root"
}

test_default_branch_bare_name() {
  local base
  base=$PWD
  mk_origin
  mk_clone
  assert_exit 0 "$WT" default-branch
  assert_eq "$OUT" main "normal clone"
  cd "$base"
  mk_bclone
  if git symbolic-ref -q refs/remotes/origin/HEAD >/dev/null; then fail "fresh bclone has origin/HEAD"; fi
  assert_exit 0 "$WT" default-branch
  assert_eq "$OUT" main "fresh bclone"
  git fetch -q origin
  git remote set-head origin main
  assert_exit 0 "$WT" default-branch
  assert_eq "$OUT" main "fetched bclone"
  git worktree add -q ../side -b side
  cd ../side
  assert_exit 0 "$WT" default-branch
  assert_eq "$OUT" main "bclone linked worktree"
  cd "$base"
  git init -q -b master plain
  cd plain
  git commit -q --allow-empty -m init
  assert_exit 0 "$WT" default-branch
  assert_eq "$OUT" master "no origin"
}

test_merged_local_only() {
  mk_origin
  mk_clone
  commit_on feat feat.txt
  assert_exit 0 "$WT" merged feat
  assert_eq "$OUT" unmerged
  git merge -q --no-ff -m merge feat
  assert_exit 0 "$WT" merged feat
  assert_eq "$OUT" "merged local"
}

test_merged_origin_only() {
  mk_origin
  mk_clone
  commit_on feat feat.txt
  git push -q origin feat:main
  if git merge-base --is-ancestor feat main; then fail "local main already has feat"; fi
  assert_exit 0 "$WT" merged feat
  assert_eq "$OUT" "merged origin"
}

test_merged_missing_ref_unknown() {
  mk_origin
  mk_clone
  assert_exit 0 "$WT" merged no-such-branch
  assert_eq "$OUT" unknown
  assert_exit 1 "$WT" merged 'bad..name'
}

test_merged_no_origin_ref() {
  git init -q -b main plain
  cd plain
  git commit -q --allow-empty -m init
  commit_on feat feat.txt
  assert_exit 0 "$WT" merged feat
  assert_eq "$OUT" unmerged
  git merge -q --no-ff -m merge feat
  assert_exit 0 "$WT" merged feat
  assert_eq "$OUT" "merged local"
}

test_base_ref_stack() {
  mk_origin
  mk_clone
  mk_map foo >/dev/null
  mk_ticket foo implementation >/dev/null
  commit_on blocker-branch b.txt
  assert_exit 0 "$WT" base-ref foo#1 --stack blocker-branch
  assert_eq "$OUT" blocker-branch
  assert_exit 3 "$WT" base-ref foo#2 --stack blocker-branch
}

test_base_ref_no_blockers_origin_strictly_ahead() {
  mk_origin
  mk_clone
  mk_map foo >/dev/null
  mk_ticket foo implementation >/dev/null
  assert_exit 0 "$WT" base-ref foo#1
  assert_eq "$OUT" main "equal refs"
  push_origin_commit ahead.txt
  assert_exit 0 "$WT" base-ref foo#1
  assert_eq "$OUT" origin/main "origin strictly ahead"
  git merge -q --ff-only origin/main
  echo local >local.txt
  git add local.txt
  git commit -qm local
  assert_exit 0 "$WT" base-ref foo#1
  assert_eq "$OUT" main "local ahead"
  push_origin_commit diverged.txt
  assert_exit 0 "$WT" base-ref foo#1
  assert_eq "$OUT" main "diverged prefers local"
}

# --- Stage C: claim protocol ---

claimed_by() {
  fm_of "$(map_path "${1%%#*}")/${1#*#}.md" '.["claimed-by"]'
}

pid_file() {
  echo "$TMPDIR/wayfinder-$AGENT_SESSION_ID/${1%%#*}-${1#*#}.pid"
}

lock_is_free() {
  flock -n "$(map_path "${1%%#*}")/${1#*#}.claim" true
}

setup_map_with_ticket() {
  mk_origin
  mk_clone
  mk_map foo >/dev/null
  mk_ticket foo "${1:-task}" >/dev/null
}

test_claim_requires_session_id() {
  setup_map_with_ticket
  new_session
  unset AGENT_SESSION_ID
  assert_unchanged "$(map_path foo)" assert_exit 1 "$WT" claim foo#1
  assert_contains "$ERR" "AGENT_SESSION_ID is not set; start the agent through claude-sandboxed or codex-sandboxed"
  assert_eq "$(claimed_by foo#1)" ""
}

test_claim_no_agent_ancestor() {
  skip_if_agent_ancestor
  setup_map_with_ticket
  new_session
  unset WAYFINDER_AGENT_PID
  assert_unchanged "$(map_path foo)" assert_exit 1 "$WT" claim foo#1
  assert_contains "$ERR" "no agent process found (looked for .claude-unwrapped, claude, codex-raw, codex)"
  assert_eq "$(claimed_by foo#1)" ""
  if "$WT" __agent-pid >/dev/null 2>&1; then fail "__agent-pid found an agent"; fi
}

test_claim_agent_pid_exited() {
  setup_map_with_ticket
  new_session
  kill_agent
  assert_unchanged "$(map_path foo)" assert_exit 1 "$WT" claim foo#1
  assert_contains "$ERR" "no agent process found (looked for .claude-unwrapped, claude, codex-raw, codex)"
  assert_eq "$(claimed_by foo#1)" ""
  lock_is_free foo#1 || fail "lock held"
}

test_concurrent_claims_one_wins() {
  local a_sid a_pid b_sid b_pid rcs w1 w2
  setup_map_with_ticket
  new_session
  a_sid=$AGENT_SESSION_ID a_pid=$WAYFINDER_AGENT_PID
  new_session
  b_sid=$AGENT_SESSION_ID b_pid=$WAYFINDER_AGENT_PID
  (
    set +e
    AGENT_SESSION_ID=$a_sid WAYFINDER_AGENT_PID=$a_pid "$WT" claim foo#1 >/dev/null 2>../err.a
    echo $? >../rc.a
  ) &
  w1=$!
  (
    set +e
    AGENT_SESSION_ID=$b_sid WAYFINDER_AGENT_PID=$b_pid "$WT" claim foo#1 >/dev/null 2>../err.b
    echo $? >../rc.b
  ) &
  w2=$!
  wait "$w1" "$w2"
  rcs=$(cat ../rc.a ../rc.b | sort | paste -sd' ' -)
  assert_eq "$rcs" "0 6" "exit codes"
  if [ "$(cat ../rc.a)" = 0 ]; then
    assert_eq "$(claimed_by foo#1)" "$a_sid"
    assert_contains "$(cat ../err.b)" "claimed by another session ($a_sid)"
  else
    assert_eq "$(claimed_by foo#1)" "$b_sid"
    assert_contains "$(cat ../err.a)" "claimed by another session ($b_sid)"
  fi
}

test_claim_reentrant_owner() {
  setup_map_with_ticket
  new_session
  assert_exit 0 "$WT" claim foo#1
  assert_eq "$OUT" ""
  assert_eq "$(claimed_by foo#1)" "$AGENT_SESSION_ID"
  [ -f "$(pid_file foo#1)" ] || fail "no pid file"
  assert_exit 0 "$WT" claim foo#1
  assert_eq "$OUT" "" "re-entrant claim prints nothing"
  assert_eq "$(claimed_by foo#1)" "$AGENT_SESSION_ID"
  if lock_is_free foo#1; then fail "lock not held"; fi
}

test_owner_killed_then_reclaim() {
  local old
  setup_map_with_ticket
  new_session
  old=$AGENT_SESSION_ID
  assert_exit 0 "$WT" claim foo#1
  kill_agent
  wait_unlocked foo 1
  new_session
  assert_exit 0 "$WT" claim foo#1
  assert_contains "$OUT" "took over stale claim from $old"
  assert_eq "$(claimed_by foo#1)" "$AGENT_SESSION_ID"
  if lock_is_free foo#1; then fail "lock not held after takeover"; fi
}

test_pid_reuse_is_stale() {
  local f
  setup_map_with_ticket
  new_session
  assert_exit 0 "$WT" claim foo#1
  f=$(pid_file foo#1)
  assert_eq "$(wc -l <"$f" | tr -d ' ')" 3
  assert_eq "$(sed -n 2p "$f")" "$WAYFINDER_AGENT_PID"
  kill -0 "$(sed -n 1p "$f")" || fail "holder not running"
  sed '3s/.*/reused process start/' "$f" >"$f.new"
  mv "$f.new" "$f"
  wait_unlocked foo 1
  kill -0 "$WAYFINDER_AGENT_PID" || fail "agent should still be alive"
}

test_reclaim_right_after_release() {
  setup_map_with_ticket
  new_session
  assert_exit 0 "$WT" claim foo#1
  assert_exit 0 "$WT" release foo#1
  assert_eq "$(claimed_by foo#1)" ""
  [ ! -e "$(pid_file foo#1)" ] || fail "pid file left behind"
  lock_is_free foo#1 || fail "lock held after release"
  assert_exit 0 "$WT" claim foo#1
  assert_exit 0 "$WT" release foo#1
  new_session
  assert_exit 0 "$WT" claim foo#1
  assert_eq "$OUT" "" "no takeover after a release"
  assert_eq "$(claimed_by foo#1)" "$AGENT_SESSION_ID"
}

test_release_rejects_non_owner() {
  local owner
  setup_map_with_ticket
  new_session
  assert_unchanged "$(map_path foo)" assert_exit 1 "$WT" release foo#1
  assert_contains "$ERR" "not owner of foo#1"
  assert_exit 0 "$WT" claim foo#1
  owner=$AGENT_SESSION_ID
  new_session
  assert_unchanged "$(map_path foo)" assert_exit 6 "$WT" release foo#1
  assert_contains "$ERR" "claimed by another session ($owner)"
  assert_unchanged "$(map_path foo)" assert_exit 1 "$WT" release foo#1 --force
}

test_claim_phase_mismatch() {
  setup_map_with_ticket implementation
  new_session
  assert_unchanged "$(map_path foo)" assert_exit 5 "$WT" claim foo#1 --phase superpowers:writing-plans
  assert_contains "$ERR" "phase is superpowers:brainstorming, expected superpowers:writing-plans"
  assert_eq "$(claimed_by foo#1)" ""
  lock_is_free foo#1 || fail "lock held after a rejected claim"
  assert_exit 0 "$WT" claim foo#1 --phase superpowers:brainstorming
  assert_unchanged "$(map_path foo)" assert_exit 5 "$WT" claim foo#1 --phase superpowers:executing-plans
  assert_contains "$ERR" "phase is superpowers:brainstorming, expected superpowers:executing-plans"
  assert_eq "$(claimed_by foo#1)" "$AGENT_SESSION_ID"
  if lock_is_free foo#1; then fail "re-entrant rejection dropped the claim"; fi
}

test_claim_blocked() {
  mk_origin
  mk_clone
  mk_map foo >/dev/null
  mk_ticket foo task >/dev/null
  mk_ticket foo task >/dev/null
  mk_ticket foo task --blocked-by 1 2 >/dev/null
  new_session
  assert_unchanged "$(map_path foo)" assert_exit 7 "$WT" claim foo#3
  assert_contains "$ERR" "blocked by 1,2"
  assert_eq "$(claimed_by foo#3)" ""
  lock_is_free foo#3 || fail "lock held after a rejected claim"
}

test_claim_failed_write_leaves_lock_free() {
  local dir
  setup_map_with_ticket
  new_session
  dir=$(map_path foo)
  chmod a-w "$dir"
  assert_exit 1 "$WT" claim foo#1
  chmod u+w "$dir"
  lock_is_free foo#1 || fail "lock held after a failed write"
  wait_unlocked foo 1
  assert_eq "$(claimed_by foo#1)" ""
  [ ! -e "$(pid_file foo#1)" ] || fail "holder started"
}

test_claim_returns_with_piped_stdout() {
  local start
  setup_map_with_ticket
  new_session
  start=$(date +%s)
  timeout 5 "$WT" claim foo#1 | cat
  [ $(($(date +%s) - start)) -lt 5 ] || fail "claim took too long"
  assert_eq "$(claimed_by foo#1)" "$AGENT_SESSION_ID"
  if lock_is_free foo#1; then fail "holder not holding the lock"; fi
}

# --- Stage D: lifecycle and upkeep ---

field() {
  fm_of "$(map_path "${1%%#*}")/${1#*#}.md" ".[\"$2\"]"
}

# to_executing <ref> [spec] [plan]: claim an implementation ticket and walk it to executing-plans.
to_executing() {
  "$WT" claim "$1" >/dev/null
  "$WT" advance "$1" superpowers:brainstorming superpowers:writing-plans ${2:+"spec=$2"}
  "$WT" advance "$1" superpowers:writing-plans superpowers:executing-plans ${3:+"plan=$3"}
}

# close_on <ref> <branch> <outcome>: close from <branch>, then switch back.
close_on() {
  local back
  back=$(git branch --show-current)
  git switch -q "$2"
  "$WT" close "$1" --evidence "$(text_file "tests pass")" --outcome "$3"
  git switch -q "$back"
}

resolve_now() {
  "$WT" claim "$1" >/dev/null
  "$WT" resolve "$1" --answer "$(text_file "${2:-answered}")"
}

test_advance_legal_edges_keep_claim() {
  mk_origin
  mk_clone
  mk_map foo >/dev/null
  mk_ticket foo implementation >/dev/null
  mk_ticket foo research:options >/dev/null
  new_session
  "$WT" claim foo#1
  mkdir docs
  echo spec >docs/s.md
  echo plan >docs/p.md
  assert_exit 0 "$WT" advance foo#1 superpowers:brainstorming superpowers:writing-plans "spec=$PWD/docs/s.md"
  assert_eq "$(field foo#1 phase)" superpowers:writing-plans
  assert_eq "$(field foo#1 spec)" "$PWD/docs/s.md"
  assert_eq "$(field foo#1 claimed-by)" "$AGENT_SESSION_ID"
  if lock_is_free foo#1; then fail "advance dropped the claim"; fi
  assert_exit 0 "$WT" advance foo#1 superpowers:writing-plans superpowers:executing-plans "plan=$PWD/docs/p.md"
  assert_eq "$(field foo#1 phase)" superpowers:executing-plans
  assert_eq "$(field foo#1 plan)" "$PWD/docs/p.md"
  assert_eq "$(field foo#1 spec)" "$PWD/docs/s.md"
  if lock_is_free foo#1; then fail "advance dropped the claim"; fi
  "$WT" claim foo#2
  assert_exit 0 "$WT" advance foo#2 research wayfinder:resolve
  assert_eq "$(field foo#2 phase)" wayfinder:resolve
  assert_exit 0 "$WT" claim foo#1 --phase superpowers:executing-plans
}

test_advance_illegal_edge_and_phase_cas() {
  local dir
  mk_origin
  mk_clone
  mk_map foo >/dev/null
  mk_ticket foo implementation >/dev/null
  mk_ticket foo task >/dev/null
  dir=$(map_path foo)
  new_session
  "$WT" claim foo#1
  "$WT" claim foo#2
  assert_unchanged "$dir" assert_exit 1 "$WT" advance foo#1 superpowers:brainstorming superpowers:executing-plans
  assert_contains "$ERR" "illegal"
  assert_unchanged "$dir" assert_exit 5 "$WT" advance foo#1 superpowers:writing-plans superpowers:executing-plans
  assert_contains "$ERR" "phase is superpowers:brainstorming, expected superpowers:writing-plans"
  assert_unchanged "$dir" assert_exit 1 "$WT" advance foo#1 superpowers:executing-plans implemented
  assert_unchanged "$dir" assert_exit 1 "$WT" advance foo#1 superpowers:writing-plans superpowers:brainstorming
  assert_unchanged "$dir" assert_exit 5 "$WT" advance foo#2 research wayfinder:resolve
  assert_unchanged "$dir" assert_exit 1 "$WT" advance foo#1 superpowers:brainstorming superpowers:writing-plans spec=relative/s.md
  assert_unchanged "$dir" assert_exit 2 "$WT" advance foo#1 superpowers:brainstorming superpowers:writing-plans bogus=1
}

test_advance_rejects_non_owner() {
  local dir owner
  mk_origin
  mk_clone
  mk_map foo >/dev/null
  mk_ticket foo implementation >/dev/null
  mk_ticket foo implementation >/dev/null
  dir=$(map_path foo)
  new_session
  assert_unchanged "$dir" assert_exit 1 "$WT" advance foo#1 superpowers:brainstorming superpowers:writing-plans
  assert_contains "$ERR" "not owner of foo#1"
  "$WT" claim foo#1
  owner=$AGENT_SESSION_ID
  new_session
  "$WT" claim foo#2
  kill_agent
  wait_unlocked foo 2
  new_session
  assert_unchanged "$dir" assert_exit 6 "$WT" advance foo#1 superpowers:brainstorming superpowers:writing-plans
  assert_contains "$ERR" "claimed by another session ($owner)"
  assert_unchanged "$dir" assert_exit 1 "$WT" advance foo#2 superpowers:brainstorming superpowers:writing-plans
  assert_contains "$ERR" "not owner of foo#2"
}

test_attach_owner_only() {
  local dir f owner
  mk_origin
  mk_clone
  mk_map foo >/dev/null
  mk_ticket foo research:fact >/dev/null
  mk_ticket foo research:fact >/dev/null
  dir=$(map_path foo)
  f=$(text_file $'## Findings\nthe answer is 42')
  new_session
  assert_unchanged "$dir" assert_exit 1 "$WT" attach foo#1 --findings "$f"
  assert_contains "$ERR" "not owner of foo#1"
  "$WT" claim foo#1
  assert_exit 0 "$WT" attach foo#1 --findings "$f"
  assert_eq "$(field foo#1 findings)" "$dir/findings/1.md"
  assert_eq "$(cat "$dir/findings/1.md")" "$(cat "$f")"
  owner=$AGENT_SESSION_ID
  new_session
  assert_unchanged "$dir" assert_exit 6 "$WT" attach foo#1 --findings "$f"
  assert_contains "$ERR" "claimed by another session ($owner)"
  resolve_now foo#2
  assert_unchanged "$dir" assert_exit 4 "$WT" attach foo#2 --findings "$f"
}

test_resolve_writes_answer_and_decision_pointer() {
  local h
  mk_origin
  mk_clone
  mk_map foo >/dev/null
  "$WT" new foo grilling "Pick a sync protocol" >/dev/null
  new_session
  "$WT" claim foo#1
  assert_exit 0 "$WT" resolve foo#1 --answer "$(text_file $'Use CRDTs.\n\nBecause offline.')"
  assert_eq "$(field foo#1 status)" closed
  assert_eq "$(field foo#1 claimed-by)" ""
  assert_eq "$(section_of "$("$WT" show foo#1)" Answer ticket | tr -s '\n')" $'\nUse CRDTs.\nBecause offline.'
  assert_contains "$(section_of "$("$WT" show-map foo)" "Decisions so far" map)" "foo#1"
  assert_contains "$(section_of "$("$WT" show-map foo)" "Decisions so far" map)" "Pick a sync protocol"
  lock_is_free foo#1 || fail "resolve left the lock held"
  [ ! -e "$(pid_file foo#1)" ] || fail "pid file left behind"
  "$WT" new foo task second >/dev/null
  resolve_now foo#2
  h=$(section_of "$("$WT" show-map foo)" "Decisions so far" map)
  assert_contains "$h" "foo#1"
  assert_contains "$h" "foo#2"
}

test_resolve_rejects_implementation_and_options_not_at_resolve() {
  local dir
  mk_origin
  mk_clone
  mk_map foo >/dev/null
  mk_ticket foo implementation >/dev/null
  mk_ticket foo research:options >/dev/null
  dir=$(map_path foo)
  new_session
  "$WT" claim foo#1
  "$WT" claim foo#2
  assert_unchanged "$dir" assert_exit 1 "$WT" resolve foo#1 --answer "$(text_file x)"
  assert_unchanged "$dir" assert_exit 5 "$WT" resolve foo#2 --answer "$(text_file x)"
  assert_contains "$ERR" "phase is research, expected wayfinder:resolve"
  "$WT" advance foo#2 research wayfinder:resolve
  assert_exit 0 "$WT" resolve foo#2 --answer "$(text_file x)"
  assert_eq "$(field foo#2 status)" closed
}

test_close_outcome_merge_records_default_branch() {
  mk_origin
  mk_clone
  mk_map foo >/dev/null
  mk_ticket foo implementation >/dev/null
  git switch -q -c feat
  new_session
  to_executing foo#1
  assert_exit 0 "$WT" close foo#1 --evidence "$(text_file "all green")" --outcome merge
  assert_eq "$(field foo#1 branch)" main
  assert_eq "$(field foo#1 phase)" implemented
  assert_eq "$(field foo#1 status)" closed
  assert_eq "$(field foo#1 claimed-by)" ""
  assert_contains "$(section_of "$("$WT" show foo#1)" "Verification evidence" ticket)" "all green"
  lock_is_free foo#1 || fail "close left the lock held"
}

test_close_outcome_pr_keep_records_current_branch() {
  mk_origin
  mk_clone
  mk_map foo >/dev/null
  mk_ticket foo implementation >/dev/null
  mk_ticket foo implementation >/dev/null
  git branch feat-a
  git branch feat-b
  new_session
  to_executing foo#1
  to_executing foo#2
  close_on foo#1 feat-a pr
  close_on foo#2 feat-b keep
  assert_eq "$(field foo#1 branch)" feat-a
  assert_eq "$(field foo#2 branch)" feat-b
  assert_eq "$(field foo#2 phase)" implemented
}

test_close_rejects_empty_evidence_missing_outcome_wrong_phase() {
  local dir
  mk_origin
  mk_clone
  mk_map foo >/dev/null
  mk_ticket foo implementation >/dev/null
  mk_ticket foo implementation >/dev/null
  dir=$(map_path foo)
  new_session
  to_executing foo#1
  assert_unchanged "$dir" assert_exit 1 "$WT" close foo#1 --evidence "$(text_file $'  \n\n')" --outcome keep
  assert_contains "$ERR" "empty"
  assert_unchanged "$dir" assert_exit 2 "$WT" close foo#1 --evidence "$(text_file ok)"
  assert_unchanged "$dir" assert_exit 2 "$WT" close foo#1 --evidence "$(text_file ok)" --outcome squash
  "$WT" claim foo#2
  assert_unchanged "$dir" assert_exit 5 "$WT" close foo#2 --evidence "$(text_file ok)" --outcome keep
  assert_contains "$ERR" "phase is superpowers:brainstorming, expected superpowers:executing-plans"
  new_session
  assert_unchanged "$dir" assert_exit 6 "$WT" close foo#1 --evidence "$(text_file ok)" --outcome keep
}

test_drop_adds_out_of_scope() {
  mk_origin
  mk_clone
  mk_map foo >/dev/null
  "$WT" new foo task "Sync over Bluetooth" >/dev/null
  assert_exit 0 "$WT" drop foo#1 --reason "no hardware for it"
  assert_eq "$(field foo#1 status)" closed
  assert_eq "$(field foo#1 superseded-by)" ""
  assert_contains "$(section_of "$("$WT" show foo#1)" Answer ticket)" "no hardware for it"
  assert_contains "$(section_of "$("$WT" show-map foo)" "Out of scope" map)" "foo#1"
  assert_contains "$(section_of "$("$WT" show-map foo)" "Out of scope" map)" "no hardware for it"
  assert_not_contains "$(section_of "$("$WT" show-map foo)" "Decisions so far" map)" "foo#1"
  new_session
  "$WT" new foo task "held" >/dev/null
  "$WT" claim foo#2
  assert_exit 0 "$WT" drop foo#2 --reason "own claim"
  assert_eq "$(field foo#2 claimed-by)" ""
  lock_is_free foo#2 || fail "drop left the lock held"
  [ ! -e "$(pid_file foo#2)" ] || fail "pid file left behind"
}

test_drop_superseded_by_rewires_open_dependents() {
  local oos
  mk_origin
  mk_clone
  mk_map foo >/dev/null
  mk_ticket foo task >/dev/null
  mk_ticket foo task >/dev/null
  mk_ticket foo task --blocked-by 1 >/dev/null
  mk_ticket foo task --blocked-by 1 >/dev/null
  mk_ticket foo task --blocked-by 1 2 >/dev/null
  "$WT" drop foo#4 --reason "closed dependent"
  oos=$(section_of "$("$WT" show-map foo)" "Out of scope" map)
  assert_exit 0 "$WT" drop foo#1 --reason "replaced by a broader ticket" --superseded-by 2
  assert_eq "$(field foo#1 superseded-by)" 2
  assert_eq "$(field foo#1 status)" closed
  assert_contains "$(section_of "$("$WT" show foo#1)" Answer ticket)" "foo#2"
  assert_eq "$(fm_of "$(map_path foo)/3.md" '.["blocked-by"] | @json')" "[2]"
  assert_eq "$(fm_of "$(map_path foo)/4.md" '.["blocked-by"] | @json')" "[1]" "closed dependent untouched"
  assert_eq "$(fm_of "$(map_path foo)/5.md" '.["blocked-by"] | @json')" "[2]"
  assert_eq "$(section_of "$("$WT" show-map foo)" "Out of scope" map)" "$oos" "no Out of scope line"
  assert_exit 1 "$WT" drop foo#5 --reason x --superseded-by 9
  assert_contains "$ERR" "id 9 not in map"
}

test_drop_superseded_by_cycle_rejects_whole_drop() {
  mk_origin
  mk_clone
  mk_map foo >/dev/null
  mk_ticket foo task >/dev/null
  mk_ticket foo task >/dev/null
  mk_ticket foo task --blocked-by 1 >/dev/null
  "$WT" block foo#2 3
  assert_unchanged "$(map_path foo)" assert_exit 1 "$WT" drop foo#1 --reason x --superseded-by 2
  assert_contains "$ERR" "cycle"
  assert_unchanged "$(map_path foo)" assert_exit 1 "$WT" drop foo#1 --reason x --superseded-by 1
}

test_block_self_and_cycle_rejected() {
  local dir
  mk_origin
  mk_clone
  mk_map foo >/dev/null
  mk_ticket foo task >/dev/null
  mk_ticket foo task >/dev/null
  mk_ticket foo task >/dev/null
  dir=$(map_path foo)
  assert_unchanged "$dir" assert_exit 1 "$WT" block foo#1 1
  assert_contains "$ERR" "cycle"
  assert_exit 0 "$WT" block foo#1 2
  assert_eq "$(fm_of "$dir/1.md" '.["blocked-by"] | @json')" "[2]"
  assert_unchanged "$dir" assert_exit 1 "$WT" block foo#2 1
  assert_contains "$ERR" "cycle"
  assert_exit 0 "$WT" block foo#2 3
  assert_unchanged "$dir" assert_exit 1 "$WT" block foo#3 1
  assert_unchanged "$dir" assert_exit 1 "$WT" block foo#1 9
  assert_contains "$ERR" "id 9 not in map"
  assert_exit 0 "$WT" block foo#1 3 2
  assert_eq "$(fm_of "$dir/1.md" '.["blocked-by"] | @json')" "[2,3]"
  assert_exit 0 "$WT" unblock foo#1 2
  assert_eq "$(fm_of "$dir/1.md" '.["blocked-by"] | @json')" "[3]"
}

test_upkeep_on_own_live_claim_keeps_claim() {
  mk_origin
  mk_clone
  mk_map foo >/dev/null
  mk_ticket foo task >/dev/null
  mk_ticket foo task >/dev/null
  new_session
  "$WT" claim foo#1
  assert_exit 0 "$WT" edit foo#1 Notes --file "$(text_file "mid-work note")"
  assert_exit 0 "$WT" block foo#1 2
  assert_eq "$(field foo#1 claimed-by)" "$AGENT_SESSION_ID"
  if lock_is_free foo#1; then fail "upkeep dropped the claim"; fi
  assert_exit 0 "$WT" unblock foo#1 2
  if lock_is_free foo#1; then fail "upkeep dropped the claim"; fi
}

test_upkeep_allowed_unclaimed_blocked_and_stale() {
  mk_origin
  mk_clone
  mk_map foo >/dev/null
  mk_ticket foo task >/dev/null
  mk_ticket foo task --blocked-by 1 >/dev/null
  mk_ticket foo task >/dev/null
  mk_ticket foo task >/dev/null
  assert_exit 0 "$WT" edit foo#2 Notes --file "$(text_file "blocked but editable")"
  assert_exit 0 "$WT" block foo#2 3
  assert_exit 0 "$WT" unblock foo#2 3
  assert_exit 0 "$WT" drop foo#2 --reason "blocked and unwanted"
  new_session
  "$WT" claim foo#4
  kill_agent
  wait_unlocked foo 4
  new_session
  assert_exit 0 "$WT" edit foo#4 Question --file "$(text_file "stale but editable")"
  assert_exit 0 "$WT" block foo#4 3
  assert_exit 0 "$WT" unblock foo#4 3
  assert_exit 0 "$WT" drop foo#4 --reason "stale and unwanted"
  assert_eq "$(field foo#4 claimed-by)" ""
}

test_upkeep_rejected_live_foreign_and_closed() {
  local dir owner
  mk_origin
  mk_clone
  mk_map foo >/dev/null
  mk_ticket foo task >/dev/null
  mk_ticket foo task >/dev/null
  mk_ticket foo task >/dev/null
  dir=$(map_path foo)
  new_session
  "$WT" claim foo#1
  owner=$AGENT_SESSION_ID
  resolve_now foo#2
  new_session
  assert_unchanged "$dir" assert_exit 6 "$WT" edit foo#1 Notes --file "$(text_file x)"
  assert_contains "$ERR" "claimed by another session ($owner)"
  assert_unchanged "$dir" assert_exit 6 "$WT" block foo#1 3
  assert_unchanged "$dir" assert_exit 6 "$WT" unblock foo#1 3
  assert_unchanged "$dir" assert_exit 6 "$WT" drop foo#1 --reason x
  assert_unchanged "$dir" assert_exit 4 "$WT" edit foo#2 Notes --file "$(text_file x)"
  assert_contains "$ERR" "ticket closed: foo#2"
  assert_unchanged "$dir" assert_exit 4 "$WT" block foo#2 3
  assert_unchanged "$dir" assert_exit 4 "$WT" unblock foo#2 3
  assert_unchanged "$dir" assert_exit 4 "$WT" drop foo#2 --reason x
}

test_resolve_and_drop_remove_proto_worktree() {
  mk_origin
  mk_clone
  mk_map foo >/dev/null
  mk_ticket foo prototype >/dev/null
  mk_ticket foo prototype >/dev/null
  git worktree add -q --detach .claude/worktrees/wayfinder-foo-1
  git worktree add -q --detach .claude/worktrees/wayfinder-foo-2
  git worktree add -q -b wayfinder-foo-1-impl .claude/worktrees/wayfinder-foo-1-impl
  echo scratch >.claude/worktrees/wayfinder-foo-1/untracked.txt
  new_session
  resolve_now foo#1 "prototype says yes"
  [ ! -e .claude/worktrees/wayfinder-foo-1 ] || fail "proto worktree dir left behind"
  assert_not_contains "$(git worktree list --porcelain)" "/wayfinder-foo-1"$'\n'
  [ -d .claude/worktrees/wayfinder-foo-1-impl ] || fail "impl worktree removed"
  [ -d .claude/worktrees/wayfinder-foo-2 ] || fail "other ticket's worktree removed"
  assert_exit 0 "$WT" drop foo#2 --reason "not needed"
  [ ! -e .claude/worktrees/wayfinder-foo-2 ] || fail "proto worktree dir left behind after drop"
  [ -d .claude/worktrees/wayfinder-foo-1-impl ] || fail "impl worktree removed"
}

test_map_complete_guards() {
  local h
  mk_origin
  mk_clone
  mk_map foo >/dev/null
  mk_ticket foo task >/dev/null
  h=$(hash_line "$("$WT" show-map foo)" "Not yet specified")
  "$WT" map-edit foo "Not yet specified" --file "$(text_file "- conflict policy")" --expect "$h"
  assert_unchanged "$(map_path foo)" assert_exit 1 "$WT" map-complete foo
  assert_contains "$ERR" "open tickets"
  new_session
  resolve_now foo#1
  assert_unchanged "$(map_path foo)" assert_exit 1 "$WT" map-complete foo
  assert_contains "$ERR" "Not yet specified"
  h=$(hash_line "$("$WT" show-map foo)" "Not yet specified")
  "$WT" map-edit foo "Not yet specified" --file "$(text_file $'  \n')" --expect "$h"
  assert_exit 0 "$WT" map-complete foo
  assert_eq "$(fm_of "$(map_path foo)/map.md" .status)" complete
  assert_eq "$("$WT" maps)" $'foo\tcomplete\t0'
  assert_exit 3 "$WT" map-complete nope
}

test_map_complete_spares_other_map_worktree() {
  mk_origin
  mk_clone
  mk_map foo >/dev/null
  mk_map foo-bar >/dev/null
  mk_ticket foo prototype >/dev/null
  mk_ticket foo-bar prototype >/dev/null
  new_session
  resolve_now foo#1
  git worktree add -q --detach .claude/worktrees/wayfinder-foo-1
  git worktree add -q --detach .claude/worktrees/wayfinder-foo-bar-1
  assert_exit 0 "$WT" map-complete foo
  [ ! -e .claude/worktrees/wayfinder-foo-1 ] || fail "leftover proto worktree not swept"
  [ -d .claude/worktrees/wayfinder-foo-bar-1 ] || fail "map-complete foo removed a foo-bar worktree"
}

test_handoff_map_removed_claim_not_found() {
  setup_map_with_ticket implementation
  rm -r "$(map_path foo)"
  new_session
  assert_exit 3 "$WT" claim foo#1 --phase superpowers:writing-plans
  assert_contains "$ERR" "not found: foo#1"
}

test_new_rejects_complete_map() {
  mk_origin
  mk_clone
  mk_map foo >/dev/null
  "$WT" map-complete foo
  assert_unchanged "$(map_path foo)" assert_exit 1 "$WT" new foo task title
  assert_contains "$ERR" "complete"
}

test_base_ref_after_local_merge() {
  mk_origin
  mk_clone
  mk_map foo >/dev/null
  mk_ticket foo implementation >/dev/null
  mk_ticket foo implementation --blocked-by 1 >/dev/null
  commit_on wayfinder-foo-1-impl one.txt
  new_session
  to_executing foo#1
  git merge -q --no-ff -m "merge foo#1" wayfinder-foo-1-impl
  close_on foo#1 wayfinder-foo-1-impl merge
  assert_eq "$(field foo#1 branch)" main
  assert_exit 0 "$WT" base-ref foo#2
  assert_eq "$OUT" main
  git merge-base --is-ancestor wayfinder-foo-1-impl "$OUT" || fail "base lacks the blocker"
}

test_base_ref_blocker_on_origin_only() {
  mk_origin
  mk_clone
  mk_map foo >/dev/null
  mk_ticket foo implementation >/dev/null
  mk_ticket foo implementation --blocked-by 1 >/dev/null
  commit_on wayfinder-foo-1-impl one.txt
  new_session
  to_executing foo#1
  close_on foo#1 wayfinder-foo-1-impl pr
  git push -q origin wayfinder-foo-1-impl:main
  assert_exit 0 "$WT" base-ref foo#2
  assert_eq "$OUT" origin/main
}

test_base_ref_diverged_rejects() {
  mk_origin
  mk_clone
  mk_map foo >/dev/null
  mk_ticket foo implementation >/dev/null
  mk_ticket foo implementation >/dev/null
  mk_ticket foo implementation --blocked-by 1 2 >/dev/null
  commit_on wayfinder-foo-1-impl one.txt
  commit_on wayfinder-foo-2-impl two.txt
  new_session
  to_executing foo#1
  to_executing foo#2
  close_on foo#1 wayfinder-foo-1-impl pr
  close_on foo#2 wayfinder-foo-2-impl pr
  git merge -q --no-ff -m "merge foo#1" wayfinder-foo-1-impl
  git push -q origin wayfinder-foo-2-impl:main
  assert_exit 1 "$WT" base-ref foo#3
  assert_contains "$ERR" "foo#1"
  assert_contains "$ERR" "foo#2"
  assert_exit 0 "$WT" base-ref foo#3 --stack wayfinder-foo-2-impl
}

test_claim_closed() {
  setup_map_with_ticket
  new_session
  resolve_now foo#1
  assert_unchanged "$(map_path foo)" assert_exit 4 "$WT" claim foo#1
  assert_contains "$ERR" "ticket closed: foo#1"
  new_session
  assert_unchanged "$(map_path foo)" assert_exit 4 "$WT" claim foo#1 --phase superpowers:executing-plans
}

test_claim_phase_wrong_checkout() {
  local root wt
  setup_map_with_ticket implementation
  root=$PWD
  git worktree add -q -b b .claude/worktrees/b
  wt=$(realpath .claude/worktrees/b)
  mkdir -p .claude/worktrees/b/docs
  echo spec >.claude/worktrees/b/docs/s.md
  new_session
  "$WT" claim foo#1
  "$WT" advance foo#1 superpowers:brainstorming superpowers:writing-plans "spec=$wt/docs/s.md"
  "$WT" release foo#1
  new_session
  assert_unchanged "$(map_path foo)" assert_exit 1 "$WT" claim foo#1 --phase superpowers:writing-plans
  assert_contains "$ERR" "spec lives in worktree $wt; restart there"
  assert_eq "$(field foo#1 claimed-by)" ""
  cd .claude/worktrees/b/docs
  assert_exit 0 "$WT" claim foo#1 --phase superpowers:writing-plans
  cd "$root"
  assert_unchanged "$(map_path foo)" assert_exit 1 "$WT" claim foo#1 --phase superpowers:writing-plans
  assert_contains "$ERR" "spec lives in worktree $wt; restart there"
  if lock_is_free foo#1; then fail "re-entrant rejection dropped the claim"; fi
}

test_claim_phase_spec_missing() {
  setup_map_with_ticket implementation
  mkdir docs
  echo spec >docs/s.md
  echo plan >docs/p.md
  new_session
  to_executing foo#1 "$PWD/docs/s.md" "$PWD/docs/p.md"
  "$WT" release foo#1
  rm docs/p.md
  new_session
  assert_unchanged "$(map_path foo)" assert_exit 1 "$WT" claim foo#1 --phase superpowers:executing-plans
  assert_contains "$ERR" "plan"
  assert_contains "$ERR" "$PWD/docs/p.md"
  assert_exit 0 "$WT" claim foo#1
}

test_takeover_at_executing_plans_then_close() {
  local old
  setup_map_with_ticket implementation
  mkdir docs
  echo spec >docs/s.md
  echo plan >docs/p.md
  new_session
  old=$AGENT_SESSION_ID
  to_executing foo#1 "$PWD/docs/s.md" "$PWD/docs/p.md"
  kill_agent
  wait_unlocked foo 1
  new_session
  assert_exit 0 "$WT" claim foo#1 --phase superpowers:executing-plans
  assert_contains "$OUT" "took over stale claim from $old"
  assert_exit 0 "$WT" close foo#1 --evidence "$(text_file "verified")" --outcome keep
  assert_eq "$(field foo#1 status)" closed
  assert_eq "$(field foo#1 branch)" main
}

test_resolve_close_drop_reject_reserved_heading() {
  local dir f
  mk_origin
  mk_clone
  mk_map foo >/dev/null
  mk_ticket foo task >/dev/null
  mk_ticket foo implementation >/dev/null
  dir=$(map_path foo)
  f=$(text_file $'fine\n## Notes\nsneaky')
  new_session
  "$WT" claim foo#1
  to_executing foo#2
  assert_unchanged "$dir" assert_exit 1 "$WT" resolve foo#1 --answer "$f"
  assert_contains "$ERR" "content contains section heading: ## Notes"
  assert_unchanged "$dir" assert_exit 1 "$WT" close foo#2 --evidence "$f" --outcome keep
  assert_contains "$ERR" "content contains section heading: ## Notes"
  assert_unchanged "$dir" assert_exit 1 "$WT" drop foo#1 --reason $'x\n## Notes'
  assert_contains "$ERR" "content contains section heading: ## Notes"
}
