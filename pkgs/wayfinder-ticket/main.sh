usage() {
  cat <<'EOF'
usage: wayfinder-ticket <command> [args...]

maps and tickets:
  map-new <slug> <title> --destination <file>
  maps
  map-edit <slug> <section> --file <file> --expect <sha256>
  map-complete <slug>
  new <slug> <type> <title> [--question <file>] [--blocked-by <id>...]
  show <slug>#<id>
  show-map <slug>
  edit <slug>#<id> <Question|Notes|Title> --file <file>
  block <slug>#<id> <id>...
  unblock <slug>#<id> <id>...
  attach <slug>#<id> --findings <file>
  frontier <slug>
  status <slug>#<id>

claims and lifecycle:
  claim <slug>#<id> [--phase <phase>]
  release <slug>#<id> [--force]
  advance <slug>#<id> <from> <to> [spec=<path>] [plan=<path>]
  resolve <slug>#<id> --answer <file>
  close <slug>#<id> --evidence <file> --outcome merge|pr|keep
  drop <slug>#<id> --reason <text> [--superseded-by <id>]

git helpers:
  main-root
  default-branch
  merged <branch>
  base-ref <slug>#<id> [--stack <branch>]
  trailer <next> [<slug> | <slug>#<id>] [--cd <dir> [--remove <worktree> [--discard]]]
EOF
}

if [ $# -eq 0 ]; then
  die 2 "usage: wayfinder-ticket <command> [args...] (see wayfinder-ticket --help)"
fi

command=$1
shift
case $command in
map-new | maps | map-edit | map-complete | new | block | unblock | show | show-map | edit | attach | claim | release | advance | resolve | close | drop | frontier | status | main-root | merged | base-ref | default-branch | trailer)
  dispatch "$command" "$@"
  ;;
-h | --help | help)
  usage
  ;;
*)
  die 2 "unknown command: $command"
  ;;
esac
