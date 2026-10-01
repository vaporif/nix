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
    "main-root" "default-branch" "merged main" "base-ref foo#1"; do
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
