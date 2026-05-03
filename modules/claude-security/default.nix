{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.claude-code.security;
  homeDir = config.home.homeDirectory;

  expandTilde = path:
    if lib.hasPrefix "~/" path
    then "${homeDir}/${lib.removePrefix "~/" path}"
    else path;

  mkDenyTriple = path: [
    "Read(${path})"
    "Write(${path})"
    "Edit(${path})"
  ];

  mkDirDeny = dir: mkDenyTriple "${expandTilde dir}/**";
  mkFileDeny = file: mkDenyTriple (expandTilde file);
  mkAbsDeny = mkDenyTriple;

  scripts = import ./scripts/wrap.nix {
    inherit pkgs lib;
    inherit (cfg.hooks.bashValidation) blockedCommands blockedSubcommands deniedSubcommands blockedPatterns;
    notificationSound = cfg.hooks.notification.sound;
    ntfyServerUrl = cfg.hooks.notification.ntfy.serverUrl;
    ntfyTopicFile = cfg.hooks.notification.ntfy.topicFile;
    ntfyEnabled = cfg.hooks.notification.ntfy.enable;
  };

  mkConfirmHook = entry: let
    hookScript = pkgs.writeShellScript "claude-confirm-${entry.tool}" ''
      ${pkgs.jq}/bin/jq -nc --arg reason ${lib.escapeShellArg entry.reason} '{
        hookSpecificOutput: {
          hookEventName: "PreToolUse",
          permissionDecision: "ask",
          permissionDecisionReason: $reason
        }
      }'
    '';
  in {
    hooks = [
      {
        command = toString hookScript;
        type = "command";
      }
    ];
    matcher = entry.tool;
  };

  bashValidationHook = {
    hooks = [
      {
        command = "${scripts.check-bash-command}/bin/claude-check-bash-command";
        type = "command";
      }
    ];
    matcher = "Bash";
  };

  notificationHook = {
    hooks = [
      {
        command = "${scripts.notify}/bin/claude-notify";
        type = "command";
      }
    ];
    matcher = "";
  };

  readGateHook = {
    hooks = [
      {
        command = "${scripts.read-gate}/bin/claude-read-gate";
        type = "command";
      }
    ];
    matcher = "Read";
  };

  editTrackHook = {
    hooks = [
      {
        command = "${scripts.edit-track}/bin/claude-edit-track";
        type = "command";
      }
    ];
    matcher = "Edit|Write";
  };

  readOnceCleanupHook = {
    hooks = [
      {
        command = "${scripts.read-once-cleanup}/bin/claude-read-once-cleanup";
        type = "command";
      }
    ];
    matcher = "";
  };

  denyList =
    (lib.concatMap mkDirDeny cfg.permissions.deniedDirectories)
    ++ (lib.concatMap mkFileDeny cfg.permissions.deniedFiles)
    ++ (lib.concatMap mkAbsDeny cfg.permissions.deniedAbsolutePaths)
    ++ (lib.map (cmd: "Bash(${cmd}:*)") cfg.permissions.deniedBashCommands)
    ++ cfg.permissions.deniedGitOperations
    ++ cfg.permissions.extraDenied;
in {
  options.programs.claude-code.security = {
    enable = lib.mkEnableOption "Claude Code security hardening";

    hooks = {
      bashValidation = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable bash command validation hook";
        };
        blockedCommands = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = ["sudo" "doas" "eval" "dd" "mkfs" "shred" "rm"];
          description = "Commands that trigger confirmation before execution";
        };
        blockedSubcommands = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = "Multi-word commands (command + subcommand) that trigger confirmation";
        };
        deniedSubcommands = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
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
          description = "Multi-word commands that are hard-blocked (denied even in unrestricted mode). The matcher does literal token-prefix matching, so flag aliases are listed explicitly. Bare-prefix rules (git clean, git restore) intentionally block all flag combinations at the cost of also blocking the rare safe forms.";
        };
        blockedPatterns = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = ["curl|sh" "curl|bash" "wget|sh" "wget|bash" "wget|python"];
          description = "Pipe patterns (source|sink) that trigger confirmation";
        };
      };

      readOnce = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable read-once hook: deny redundant file reads using sha256 content hashing";
        };
      };

      notification = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable notification hook";
        };
        sound = lib.mkOption {
          type = lib.types.str;
          default = "Glass";
          description = "macOS notification sound name";
        };
        ntfy = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable phone push notifications via ntfy";
          };
          serverUrl = lib.mkOption {
            type = lib.types.str;
            default = "ntfy.sh";
            description = "ntfy server URL";
          };
          topicFile = lib.mkOption {
            type = lib.types.nullOr lib.types.path;
            default = null;
            description = "Path to file containing ntfy topic name";
          };
        };
      };
    };

    permissions = {
      deniedDirectories = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "~/.ssh"
          "~/.aws"
          "~/.kube"
          "~/.gnupg"
          "~/.config/sops"
          "~/.config/gh"
          "~/.config/gcloud"
          "~/.config/Bitwarden CLI"
          "~/Library/Keychains"
          "~/Library/Messages"
          "~/Library/Mail"
          "~/Library/Calendars"
          "~/Library/Application Support/AddressBook"
          "~/Library/Application Support/Bitwarden"
          "~/Library/Application Support/Signal"
          "~/Library/Application Support/Slack"
          "~/Library/Application Support/discord"
          "~/Library/Application Support/obsidian"
          "~/Library/Application Support/BraveSoftware"
          "~/Library/Application Support/LibreWolf"
          "~/Library/Application Support/TorBrowser-Data"
          "~/Library/Application Support/Spotify"
          "~/Library/Application Support/Steam"
          "~/Library/Application Support/zoom.us"
          "~/Library/Application Support/Element"
          "~/Library/Application Support/Simplex"
          "~/Library/Group Containers/*proton*"
          "~/Library/Group Containers/*WhatsApp*"
          "~/Library/Group Containers/group.com.apple.notes"
          "~/Library/Containers/com.apple.Notes"
          "~/.local/share/atuin"
          "~/.bash_sessions"
        ];
        description = ''
          Directories denied for Read/Write/Edit. Each generates 3 deny rules with /** glob suffix.
          Denying a nonexistent path is a no-op in Claude Code, so cross-platform defaults are harmless.
        '';
      };

      deniedFiles = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "~/.netrc"
          "~/.npmrc"
          "~/.pypirc"
          "~/.docker/config.json"
          "~/.zsh_history"
          "~/.bash_history"
        ];
        description = "Individual files denied for Read/Write/Edit. Each generates 3 deny rules (no glob).";
      };

      deniedAbsolutePaths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = ["/run/secrets/**"];
        description = "Absolute paths denied for Read/Write/Edit. Used as-is (no tilde expansion).";
      };

      deniedBashCommands = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = ["git push" "git push *"];
        description = "Bash commands to deny. Each generates a Bash(<cmd>:*) deny rule.";
      };

      deniedGitOperations = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = ["mcp__git__git_add" "mcp__git__git_commit" "mcp__git__git_reset" "mcp__git__git_checkout"];
        description = "MCP git tool names to deny";
      };

      extraDenied = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Additional raw deny rules merged with generated defaults";
      };

      allowedTools = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "Bash(ls:*)"
          "Bash(head:*)"
          "Bash(tail:*)"
          "Bash(wc:*)"
          "Bash(file:*)"
          "Bash(pwd:*)"
          "Bash(whoami:*)"
          "Bash(uname:*)"
          "Bash(date:*)"
          "Bash(which:*)"
          "Bash(type:*)"
          "Bash(eza:*)"
          "Bash(bat:*)"
          "Bash(fd:*)"
          "Bash(find:*)"
          "Bash(rg:*)"
          "Bash(grep:*)"
          "Bash(sort:*)"
          "Bash(uniq:*)"
          "Bash(cut:*)"
          "Bash(tr:*)"
          "Bash(tee:*)"
          "Bash(xargs:*)"
          "Bash(awk:*)"
          "Bash(sed:*)"
          "Bash(diff:*)"
          "Bash(comm:*)"
          "Bash(jq:*)"
          "Bash(du:*)"
          "Bash(df:*)"
          "Bash(realpath:*)"
          "Bash(readlink:*)"
          "Bash(basename:*)"
          "Bash(dirname:*)"
          "Bash(hostname:*)"
          "Bash(sw_vers:*)"
          "Bash(shasum:*)"
          "Bash(man:*)"
          "Bash(tokei:*)"
          "Bash(just:*)"
          "Bash(typos:*)"
          "Bash(taplo:*)"
          "Bash(shellcheck:*)"
          "Bash(actionlint:*)"
          "Bash(gitleaks:*)"
          "Bash(nix-tree:*)"
          "Bash(nix-diff:*)"
          "Bash(nix-search:*)"
          "Bash(gh pr view:*)"
          "Bash(gh pr list:*)"
          "Bash(gh pr status:*)"
          "Bash(gh pr diff:*)"
          "Bash(gh pr checks:*)"
          "Bash(gh issue view:*)"
          "Bash(gh issue list:*)"
          "Bash(gh issue status:*)"
          "Bash(gh repo view:*)"
          "Bash(gh repo list:*)"
          "Bash(gh run view:*)"
          "Bash(gh run list:*)"
          "Bash(gh release view:*)"
          "Bash(gh release list:*)"
          "Bash(gh workflow view:*)"
          "Bash(gh workflow list:*)"
          "Bash(gh label list:*)"
          "Bash(gh milestone view:*)"
          "Bash(gh milestone list:*)"
          "Bash(gh cache list:*)"
          "Bash(gh run watch:*)"
          "Bash(gh extension list:*)"
          "Bash(gh status:*)"
          "Bash(gh api:*)"
          "Bash(gh auth status:*)"
          "Bash(gh search:*)"
          "Bash(git log:*)"
          "Bash(git status:*)"
          "Bash(git diff:*)"
          "Bash(git show:*)"
          "Bash(git branch:*)"
          "Bash(git remote:*)"
          "Bash(git tag:*)"
          "Bash(git stash list:*)"
          "Bash(git rev-parse:*)"
          "Bash(git ls-files:*)"
          "Bash(git blame:*)"
          "Bash(git shortlog:*)"
          "Bash(procs:*)"
          "Bash(btop:*)"
          "Bash(delta:*)"
          "Bash(difftastic:*)"
          "Bash(nix flake show:*)"
          "Bash(nix flake metadata:*)"
          "Bash(nix flake info:*)"
          "Bash(nix flake check:*)"
          "Bash(nix search:*)"
          "Bash(nix derivation show:*)"
          "Bash(nix why-depends:*)"
          "Bash(nix path-info:*)"
          "Bash(nix store ls:*)"
          "Bash(nix store diff-closures:*)"
          "Bash(nix profile list:*)"
          "Bash(nix registry list:*)"
          "Bash(nix log:*)"
          "Bash(nix hash:*)"
          "Bash(nix eval:*)"
          "Bash(nix build:*)"
          "Bash(nix repl:*)"
          "Bash(nix-store --query:*)"
          "Bash(nix-store -q:*)"
          "Bash(nix-instantiate --eval:*)"
          "Bash(cargo check:*)"
          "Bash(cargo test:*)"
          "Bash(cargo clippy:*)"
          "Bash(cargo fmt --check:*)"
          "Bash(cargo run:*)"
          "Bash(cargo bench:*)"
          "Bash(cargo doc:*)"
          "Bash(cargo tree:*)"
          "Bash(cargo metadata:*)"
          "Bash(go build:*)"
          "Bash(go test:*)"
          "Bash(go run:*)"
          "Bash(go list:*)"
          "Bash(go mod graph:*)"
          "Bash(go doc:*)"
          "Bash(go vet:*)"
          "Bash(forge build:*)"
          "Bash(forge test:*)"
          "Bash(forge doc:*)"
          "Bash(cast call:*)"
          "Bash(cast decode:*)"
          "Bash(cast abi-encode:*)"
          "Bash(cast abi-decode:*)"
          "Bash(cast sig:*)"
          "Bash(cast interface:*)"
          "Bash(cast chain-id:*)"
          "Bash(alejandra:*)"
          "Bash(statix:*)"
          "Bash(deadnix:*)"
          "Bash(selene:*)"
          "Bash(stylua:*)"
          "Read"
          "Glob"
          "Grep"
          "WebFetch"
          "WebSearch"
          "Read(//nix/store/**)"
          "mcp__filesystem__read_file"
          "mcp__filesystem__read_text_file"
          "mcp__filesystem__read_media_file"
          "mcp__filesystem__read_multiple_files"
          "mcp__filesystem__list_directory"
          "mcp__filesystem__list_directory_with_sizes"
          "mcp__filesystem__directory_tree"
          "mcp__filesystem__search_files"
          "mcp__filesystem__get_file_info"
          "mcp__filesystem__list_allowed_directories"
          "mcp__git__git_status"
          "mcp__git__git_diff_unstaged"
          "mcp__git__git_diff_staged"
          "mcp__git__git_diff"
          "mcp__git__git_log"
          "mcp__git__git_show"
          "mcp__git__git_branch"
          "mcp__github__get_file_contents"
          "mcp__github__get_commit"
          "mcp__github__get_me"
          "mcp__github__get_tag"
          "mcp__github__get_label"
          "mcp__github__get_latest_release"
          "mcp__github__get_release_by_tag"
          "mcp__github__get_team_members"
          "mcp__github__get_teams"
          "mcp__github__list_branches"
          "mcp__github__list_commits"
          "mcp__github__list_issues"
          "mcp__github__list_pull_requests"
          "mcp__github__list_releases"
          "mcp__github__list_tags"
          "mcp__github__list_issue_types"
          "mcp__github__issue_read"
          "mcp__github__pull_request_read"
          "mcp__github__search_code"
          "mcp__github__search_issues"
          "mcp__github__search_pull_requests"
          "mcp__github__search_repositories"
          "mcp__github__search_users"
          "mcp__serena__activate_project"
          "mcp__serena__check_onboarding_performed"
          "mcp__serena__get_current_config"
          "mcp__serena__list_dir"
          "mcp__serena__read_file"
          "mcp__serena__read_memory"
          "mcp__serena__list_memories"
          "mcp__serena__find_file"
          "mcp__serena__get_symbols_overview"
          "mcp__serena__find_symbol"
          "mcp__serena__find_referencing_symbols"
          "mcp__serena__search_for_pattern"
          "mcp__serena__initial_instructions"
          "mcp__serena__onboarding"
          "mcp__serena__think_about_collected_information"
          "mcp__serena__think_about_task_adherence"
          "mcp__serena__think_about_whether_you_are_done"
          "mcp__serena__write_memory"
          "mcp__serena__edit_memory"
          "mcp__serena__delete_memory"
          "mcp__tavily__tavily-search"
          "mcp__tavily__tavily-extract"
          "mcp__tavily__tavily-crawl"
          "mcp__tavily__tavily-map"
          "mcp__context7__resolve-library-id"
          "mcp__context7__get-library-docs"
          "mcp__memory__read_graph"
          "mcp__memory__search_nodes"
          "mcp__memory__open_nodes"
          "mcp__memory__create_entities"
          "mcp__memory__create_relations"
          "mcp__memory__add_observations"
          "mcp__nixos__nixos_search"
          "mcp__nixos__nixos_info"
          "mcp__nixos__nixos_channels"
          "mcp__nixos__nixos_stats"
          "mcp__nixos__home_manager_search"
          "mcp__nixos__home_manager_info"
          "mcp__nixos__home_manager_stats"
          "mcp__nixos__home_manager_list_options"
          "mcp__nixos__home_manager_options_by_prefix"
          "mcp__nixos__darwin_search"
          "mcp__nixos__darwin_info"
          "mcp__nixos__darwin_stats"
          "mcp__nixos__darwin_list_options"
          "mcp__nixos__darwin_options_by_prefix"
          "mcp__nixos__nixos_flakes_stats"
          "mcp__nixos__nixos_flakes_search"
          "mcp__nixos__nixhub_package_versions"
          "mcp__nixos__nixhub_find_version"
          "mcp__time__get_current_time"
          "mcp__time__convert_time"
          "mcp__sequential-thinking__sequentialthinking"
          "mcp__ferrex__store"
          "mcp__ferrex__recall"
          "mcp__ferrex__forget"
          "mcp__ferrex__reflect"
          "mcp__ferrex__stats"
        ];
        description = "Tools pre-approved for use without confirmation";
      };

      extraAllowed = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Additional allow rules merged with defaults";
      };

      confirmBeforeWrite = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            tool = lib.mkOption {
              type = lib.types.str;
              description = "Tool matcher (regex matched against tool name)";
            };
            reason = lib.mkOption {
              type = lib.types.str;
              description = "Human-readable reason shown in the confirmation prompt";
            };
          };
        });
        default = [
          {
            tool = "mcp__filesystem__delete_file";
            reason = "This will delete a file. Confirm this is intended before proceeding.";
          }
          {
            tool = "mcp__ferrex__store";
            reason = "Storing to ferrex memory. This persists across sessions.";
          }
          {
            tool = "mcp__ferrex__forget";
            reason = "Deleting from ferrex memory. This is irreversible.";
          }
          {
            tool = "mcp__serena__write_memory";
            reason = "Writing to persistent Serena memory.";
          }
          {
            tool = "mcp__serena__edit_memory";
            reason = "Editing persistent Serena memory.";
          }
          {
            tool = "mcp__serena__delete_memory";
            reason = "Deleting persistent Serena memory.";
          }
        ];
        description = "Tools that require explicit user confirmation via PreToolUse hook, with human-readable reasons";
      };
    };

    settingsFragment = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      readOnly = true;
      internal = true;
      description = "Generated settings.json fragment (hooks + deny permissions)";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.hooks.notification.ntfy.enable -> cfg.hooks.notification.ntfy.topicFile != null;
        message = "programs.claude-code.security.hooks.notification.ntfy.topicFile must be set when ntfy is enabled";
      }
    ];
    programs.claude-code.security.settingsFragment = {
      hooks = {
        PreToolUse =
          (lib.optional cfg.hooks.bashValidation.enable bashValidationHook)
          ++ (lib.optional cfg.hooks.readOnce.enable readGateHook)
          ++ (lib.map mkConfirmHook cfg.permissions.confirmBeforeWrite);
        PostToolUse = lib.optional cfg.hooks.readOnce.enable editTrackHook;
        SessionStart = lib.optional cfg.hooks.readOnce.enable readOnceCleanupHook;
        Notification = lib.optional cfg.hooks.notification.enable notificationHook;
        # Declared empty so the fragment-coverage test in tests/claude-settings.nix
        # forces the splice in home/common/claude/settings.nix to keep handling
        # this key — adding entries here will land in settings.json automatically.
        UserPromptSubmit = [];
      };
      permissions = {
        allow = cfg.permissions.allowedTools ++ cfg.permissions.extraAllowed;
        deny = denyList;
      };
    };
  };
}
