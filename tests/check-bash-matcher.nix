{pkgs}: let
  hookScript =
    (import ../modules/claude-security/scripts/wrap.nix {
      inherit pkgs;
      inherit (pkgs) lib;
      blockedCommands = ["sudo" "doas" "eval" "dd" "mkfs" "shred"];
      blockedSubcommands = [];
      deniedSubcommands = [
        "git push"
        "git reset --hard"
        "git reset --merge"
        "git reset --keep"
        "git rebase -i"
        "git rebase --interactive"
        "git checkout --"
        "git restore"
        "git clean"
        "git filter-branch"
        "git filter-repo"
        "git update-ref -d"
        "git update-ref --stdin"
      ];
      blockedPatterns = ["curl|sh" "curl|bash"];
      notificationSound = "Glass";
      ntfyServerUrl = "";
      ntfyTopicFile = null;
      ntfyEnabled = false;
    })
    .check-bash-command;
in
  pkgs.runCommand "check-bash-matcher-test" {} ''
    set -euo pipefail
    fail=0

    # Bypass payloads: every entry must produce deny or ask, never allow.
    while IFS= read -r payload; do
      [ -z "$payload" ] && continue
      input=$(${pkgs.jq}/bin/jq -nc --arg cmd "$payload" '{tool_input: {command: $cmd}}')
      result=$(echo "$input" | ${hookScript}/bin/claude-check-bash-command || true)
      decision=$(echo "$result" | ${pkgs.jq}/bin/jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null || true)
      if [ "$decision" != "deny" ] && [ "$decision" != "ask" ]; then
        echo "BYPASS: payload=[$payload] decision=[$decision] out=[$result]" >&2
        fail=1
      fi
    done < ${../modules/claude-security/scripts/test-fixtures/bypass-payloads.txt}

    # Should-allow payloads: every entry must produce empty output (allow path).
    # Catches false-positive opacity-asks on benign quoted args.
    while IFS= read -r payload; do
      [ -z "$payload" ] && continue
      input=$(${pkgs.jq}/bin/jq -nc --arg cmd "$payload" '{tool_input: {command: $cmd}}')
      result=$(echo "$input" | ${hookScript}/bin/claude-check-bash-command || true)
      decision=$(echo "$result" | ${pkgs.jq}/bin/jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null || true)
      if [ -n "$decision" ]; then
        echo "FRICTION: payload=[$payload] decision=[$decision] out=[$result]" >&2
        fail=1
      fi
    done < ${../modules/claude-security/scripts/test-fixtures/should-allow-payloads.txt}

    [ "$fail" = "0" ] || exit 1
    touch $out
  ''
