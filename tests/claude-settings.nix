# Integration test for Claude settings.json assembly.
# Verifies that the security settingsFragment is properly merged
# with custom hooks into the final settings.json structure.
#
# Also includes a Nix-level evalModules test that asserts mkConfirmHook
# safely handles apostrophes in `reason` (regression guard for the
# JSON-injection vulnerability fixed by switching to `jq --arg`).
{
  pkgs,
  home-manager,
  ...
}: let
  vmTest = pkgs.testers.nixosTest {
    name = "claude-settings";

    nodes.machine = {...}: {
      imports = [home-manager.nixosModules.home-manager];

      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        users.testuser = {config, ...}: let
          sec = config.programs.claude-code.security.settingsFragment;
        in {
          imports = [../claude/security];

          home.stateVersion = "24.11";

          programs.claude-code.security = {
            enable = true;
            hooks.notification.ntfy = {
              enable = true;
              topicFile = "/run/secrets/ntfy-topic";
            };
          };

          # Replicate the merge logic from claude/home.nix
          home.file.".claude/settings.json".text = builtins.toJSON {
            "$schema" = "https://json.schemastore.org/claude-code-settings.json";
            hooks = {
              PreToolUse =
                sec.hooks.PreToolUse
                ++ [
                  {
                    hooks = [
                      {
                        command = "echo custom-hook";
                        type = "command";
                      }
                    ];
                    matcher = "Bash";
                  }
                ];
              PostToolUse = [
                {
                  hooks = [
                    {
                      command = "claude-formatter";
                      type = "command";
                    }
                  ];
                  matcher = "Edit|Write";
                }
              ];
              inherit (sec.hooks) Notification;
            };
            permissions = {
              inherit (sec.permissions) allow deny;
            };
            enabledPlugins = {
              "test-plugin@nix-plugins" = true;
            };
          };
        };
      };

      users.users.testuser = {
        isNormalUser = true;
        home = "/home/testuser";
      };
    };

    testScript = let
      settings = "/home/testuser/.claude/settings.json";
    in ''
      machine.wait_for_unit("multi-user.target")

      # Test 1: settings.json exists and is valid JSON
      machine.succeed("jq . ${settings}")

      # Test 2: Has $schema field
      machine.succeed("jq -e '.[\"$schema\"]' ${settings}")

      # Test 3: PreToolUse contains security bash validation hook
      machine.succeed("jq -e '.hooks.PreToolUse[] | select(.matcher == \"Bash\") | .hooks[0].command' ${settings}")

      # Test 4: PreToolUse contains both security AND custom hooks
      hook_count = int(machine.succeed("jq '.hooks.PreToolUse | length' ${settings}").strip())
      assert hook_count >= 2, f"Expected at least 2 PreToolUse hooks (security + custom), got {hook_count}"

      # Test 5: Custom hook is present alongside security hook
      machine.succeed("jq -e '.hooks.PreToolUse[] | select(.hooks[0].command == \"echo custom-hook\")' ${settings}")

      # Test 6: PostToolUse has claude-formatter hook
      machine.succeed("jq -e '.hooks.PostToolUse[] | select(.hooks[0].command == \"claude-formatter\")' ${settings}")

      # Test 7: Notification hook exists
      machine.succeed("jq -e '.hooks.Notification | length > 0' ${settings}")

      # Test 8: permissions.deny is populated from security module
      deny_count = int(machine.succeed("jq '.permissions.deny | length' ${settings}").strip())
      assert deny_count > 0, f"Expected deny list to have entries from security module, got {deny_count}"

      # Test 9: permissions.allow exists
      machine.succeed("jq -e '.permissions.allow' ${settings}")

      # Test 10: enabledPlugins field is present
      machine.succeed("jq -e '.enabledPlugins' ${settings}")

      # Test 11: Security deny entries are expanded (no literal ~)
      machine.succeed("jq -e '[.permissions.deny[] | select(contains(\"~\"))] | length == 0' ${settings}")

      # Test 12: Bash validation hook script is executable
      bash_hook_cmd = machine.succeed("jq -r '.hooks.PreToolUse[] | select(.matcher == \"Bash\") | .hooks[0].command' ${settings}").strip().split("\n")[0]
      machine.succeed(f"test -x {bash_hook_cmd}")
    '';
  };

  # Regression test for the mkConfirmHook apostrophe-injection bug:
  # render the hook with an apostrophe-bearing reason and assert the
  # generated script emits valid JSON with the reason preserved verbatim.
  evaluatedSecurity = pkgs.lib.evalModules {
    modules = [
      ../claude/security
      # evalModules has no host schema, so stub the minimum HM/NixOS
      # surface the module reads (homeDirectory) or writes (assertions).
      ({lib, ...}: {
        options.home.homeDirectory = lib.mkOption {
          type = lib.types.str;
          default = "/home/testuser";
        };
        options.assertions = lib.mkOption {
          type = lib.types.listOf lib.types.unspecified;
          default = [];
        };
      })
      {
        _module.args = {inherit pkgs;};
        programs.claude-code.security = {
          enable = true;
          permissions.confirmBeforeWrite = [
            {
              tool = "Edit";
              reason = "Don't allow this";
            }
          ];
        };
      }
    ];
  };

  confirmHookApostropheTest = let
    preHooks = evaluatedSecurity.config.programs.claude-code.security.settingsFragment.hooks.PreToolUse;
    confirmEntry = builtins.head (builtins.filter (h: h.matcher == "Edit") preHooks);
    hookCommand = (builtins.head confirmEntry.hooks).command;
  in
    pkgs.runCommand "mkConfirmHook-apostrophe" {} ''
      set -euo pipefail
      hook_out=$(${hookCommand})
      echo "$hook_out" | ${pkgs.jq}/bin/jq -e \
        '.hookSpecificOutput.permissionDecisionReason == "Don'\'''t allow this"' \
        >/dev/null \
        || { echo "FAIL: hook output [$hook_out] missing exact reason" >&2; exit 1; }
      echo "$hook_out" | ${pkgs.jq}/bin/jq -e \
        '.hookSpecificOutput.hookEventName == "PreToolUse"
         and .hookSpecificOutput.permissionDecision == "ask"' \
        >/dev/null \
        || { echo "FAIL: hook output [$hook_out] missing event/decision fields" >&2; exit 1; }
      touch "$out"
    '';

  # Fragment → settings splice contract: every hook key declared in
  # settingsFragment.hooks must appear in the rendered settings.json.
  # Catches the case where someone adds a new hook key to the fragment
  # but forgets to splice it in claude/home/settings.nix.
  fragmentCoverageTest = let
    sec = evaluatedSecurity.config.programs.claude-code.security.settingsFragment;
    # Mirrors the splice in claude/home/settings.nix (both darwin
    # and linux branches) so the test exercises real-config output.
    parryHook = {
      hooks = [
        {
          command = "parry-guard hook";
          type = "command";
        }
      ];
    };
    renderHooksFor = isDarwin: {
      PreToolUse =
        sec.hooks.PreToolUse
        ++ pkgs.lib.optionals isDarwin [
          (parryHook // {matcher = "Bash|Read|Write|Edit|Glob|Grep|WebFetch|WebSearch|NotebookEdit|Task|mcp__.*";})
        ];
      PostToolUse =
        sec.hooks.PostToolUse
        ++ [
          {
            hooks = [
              {
                command = "claude-formatter";
                type = "command";
              }
            ];
            matcher = "Edit|Write";
          }
        ]
        ++ pkgs.lib.optionals isDarwin [
          (parryHook // {matcher = "Read|WebFetch|Bash|mcp__github__get_file_contents|mcp__filesystem__read_file|mcp__filesystem__read_text_file";})
        ];
      inherit (sec.hooks) Notification SessionStart;
      UserPromptSubmit =
        sec.hooks.UserPromptSubmit
        ++ pkgs.lib.optionals isDarwin [
          (parryHook // {matcher = "";})
        ];
    };
    fragmentJson = pkgs.writeText "fragment-hooks.json" (builtins.toJSON sec.hooks);
    renderedDarwinJson = pkgs.writeText "rendered-darwin-hooks.json" (builtins.toJSON (renderHooksFor true));
    renderedLinuxJson = pkgs.writeText "rendered-linux-hooks.json" (builtins.toJSON (renderHooksFor false));
  in
    pkgs.runCommand "fragment-coverage" {} ''
      set -euo pipefail
      fragment_keys=$(${pkgs.jq}/bin/jq -r 'keys[]' < ${fragmentJson})
      for rendered in ${renderedDarwinJson} ${renderedLinuxJson}; do
        rendered_keys=$(${pkgs.jq}/bin/jq -r 'keys[]' < "$rendered")
        for k in $fragment_keys; do
          echo "$rendered_keys" | grep -qFx "$k" || {
            echo "FAIL: fragment hook '$k' missing in $rendered" >&2
            echo "fragment keys: $fragment_keys" >&2
            echo "rendered keys: $rendered_keys" >&2
            exit 1
          }
        done
      done
      touch "$out"
    '';
in
  pkgs.runCommand "claude-settings" {
    passthru = {
      inherit vmTest confirmHookApostropheTest fragmentCoverageTest;
    };
  } ''
    # Force all checks to be built as dependencies of this aggregate.
    echo ${vmTest} > /dev/null
    echo ${confirmHookApostropheTest} > /dev/null
    echo ${fragmentCoverageTest} > /dev/null
    touch $out
  ''
