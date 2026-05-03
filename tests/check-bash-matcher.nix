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
        "git rebase -i"
        "git checkout --"
        "git clean"
        "git filter-branch"
        "git update-ref -d"
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
    while IFS= read -r payload; do
      [ -z "$payload" ] && continue
      input=$(${pkgs.jq}/bin/jq -nc --arg cmd "$payload" '{tool_input: {command: $cmd}}')
      out=$(echo "$input" | ${hookScript}/bin/claude-check-bash-command || true)
      decision=$(echo "$out" | ${pkgs.jq}/bin/jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null || true)
      if [ "$decision" != "deny" ] && [ "$decision" != "ask" ]; then
        echo "BYPASS: payload=[$payload] decision=[$decision] out=[$out]" >&2
        fail=1
      fi
    done < ${../modules/claude-security/scripts/test-fixtures/bypass-payloads.txt}
    [ "$fail" = "0" ] || exit 1
    touch $out
  ''
