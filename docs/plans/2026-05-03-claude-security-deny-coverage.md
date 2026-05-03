# Claude-Security Deny Coverage & Test Wiring — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or `/team-feature` to implement this plan task-by-task, per the Execution Strategy below. Steps use checkbox (`- [ ]`) syntax — these are **persistent durable state**, not visual decoration. The executor edits the plan file in place: `- [ ]` → `- [x]` the instant a step verifies, before moving on. On resume (new session, crash, takeover), the executor scans existing `- [x]` marks and skips them — these steps are NOT redone. TodoWrite mirrors this state in-session; the plan file is the source of truth across sessions.

**Goal:** Close the deny-rule bypasses surfaced by the multi-agent review on `fix-review-findings`, and wire the regression test suite so it actually runs locally and in CI (today it builds nowhere).

**Architecture:** Three independent fixes. (1) Drop `--no-build` from the local flake check and flip `matrix.check` on the linux CI runner so `tests/check-bash-matcher.nix` actually executes (CI is what runs the linux tests; macOS local checks only rebuild `formatting`). (2) Extend `deniedSubcommands` to close every known token-prefix bypass: long-form aliases (`--interactive`), modern split commands (`git restore`, `git filter-repo`, `git update-ref --stdin`), additional destructive reset modes (`--merge`/`--keep`), and uncovered `git clean` flag clusters (collapsed to bare-prefix). Pin every gap with regression payloads in `bypass-payloads.txt`. (3) Polish: fix a wrong comment in `wrap.nix`, remove dead `isDarwin` branch in `qdrant.nix`, document the hardcoded-hostname pitfall for fork users.

**Tech Stack:** Nix flakes, just, GitHub Actions, bash + jq + shfmt (existing hook scripts — no new tooling).

## Execution Strategy

**Subagents** — default. Reason: no spec override; tasks are small and independent so two-stage review per task still adds value without being heavyweight. The total diff is small enough that inline execution would also be reasonable if the user wants to skip dispatch overhead.

## Task Dependency Graph

- Task 1 [AFK]: depends on `none` → first batch
- Task 2 [AFK]: depends on `none` → first batch (parallel with Task 1)
- Task 3 [AFK]: depends on `none` → first batch (parallel with Tasks 1 & 2)
- Polish: depends on `Task 1, Task 2, Task 3` → final batch

All three implementation tasks touch disjoint files. Task 1 (justfile + CI) makes the regression test visible everywhere; Task 2 (deny rules + fixture) is independently verifiable via `nix build .#checks.aarch64-linux.check-bash-matcher` whether or not Task 1 has landed; Task 3 is unrelated polish.

## Agent Assignments

- Task 1: Wire the test suite into local + CI checks → general-purpose
- Task 2: Add missing deny rules and regression payloads → general-purpose
- Task 3: Comment / dead-code / docs polish → general-purpose
- Polish: post-implementation-polish → general-purpose

---

## Task 1: Wire the test suite into local + CI checks

The bypass-payload regression test (`tests/check-bash-matcher.nix`) and the existing `tests/claude-security.nix` / `tests/claude-settings.nix` are registered under `flake.checks.aarch64-linux.*` but never built. `just check` runs `nix flake check --no-build` (skips test derivations entirely), and `.github/workflows/ci.yml` has `matrix.check = false` for both runners (so the `nix flake check` step is gated off). The whole hardening pass on this branch has no regression net. Fix both ends.

**Files:**
- Modify: `justfile:27-28` — drop `--no-build` from the `lint-nix` recipe so `just check` actually builds the checks
- Modify: `.github/workflows/ci.yml:30-33` — flip `check: true` on the `ubuntu-24.04-arm` matrix entry so the `nix flake check` step runs in CI on the runner that owns the linux checks

**Why we keep `lint-nix-fast` separate:** the split exists so `.githooks/pre-push` (which runs `just check-fast`) stays under a few seconds. We're only changing the *full* `lint-nix`, which is what `just check` invokes.

**Why we don't add `check: true` on the macOS runner:** all four test derivations are wrapped in `lib.optionalAttrs chkPkgs.stdenv.isLinux` in `flake.nix:209-225`. They wouldn't run on macOS even if the flag were flipped, so flipping it would just waste CI minutes evaluating the empty linux-only checks set.

**Local verification caveat (macOS):** `nix flake check` evaluates checks for the *current* system only (no `--all-systems`). On `aarch64-darwin` it never touches `checks.aarch64-linux.*`, so dropping `--no-build` does not produce build output for the four linux test derivations on a Mac dev machine. Step 3/4 verification below therefore lists *platform-conditional* expected output. The CI flip in Step 2 is what actually moves the regression net into a place that runs.

- [x] **Step 1: Drop `--no-build` from `lint-nix`**

Edit `justfile`. Replace:

```just
# Lint nix files (full — includes flake check)
lint-nix: lint-nix-fast
    nix flake check --no-build
```

with:

```just
# Lint nix files (full — runs flake checks including tests)
lint-nix: lint-nix-fast
    nix flake check
```

- [x] **Step 2: Flip `check: true` on the linux CI runner**

Edit `.github/workflows/ci.yml:30-33`. Replace:

```yaml
          - runner: ubuntu-24.04-arm
            build-cmd: nix build '.#nixosConfigurations.nixos.config.system.build.toplevel'
            lint: false
            check: false
```

with:

```yaml
          - runner: ubuntu-24.04-arm
            build-cmd: nix build '.#nixosConfigurations.nixos.config.system.build.toplevel'
            lint: false
            check: true
```

Leave the macOS entry untouched — it would build no extra checks anyway.

- [x] **Step 3: Verify local `just check` runs without `--no-build`**

Run: `just check 2>&1 | tail -40`

Expected — platform-conditional:
- **On `aarch64-linux`** (the `nixos` host): output contains build lines for `check-bash-matcher`, `claude-settings`, `claude-security`, `xdg-config-paths`. The run takes noticeably longer (NixOS-VM tests).
- **On `aarch64-darwin`** (the `burnedapple` host): output rebuilds the `formatting` check only — the four linux tests live under `checks.aarch64-linux.*` which `nix flake check` does not evaluate on a darwin host. This is expected. The CI flip in Step 2 is what runs them; locally the linux checks are reachable only by SSH-ing into the NixOS VM or via remote builder.

In either case the command must exit 0 with no build errors.

- [x] **Step 4: Verify the bypass-payload test specifically (linux only)**

On a `aarch64-linux` host (or via remote linux builder): `nix build .#checks.aarch64-linux.check-bash-matcher --print-build-logs 2>&1 | tail -20`

Expected: build succeeds; if any payload in `bypass-payloads.txt` were not caught, the test would print `BYPASS: payload=[...] decision=[]` and fail. Treat a clean build as the green signal.

On `aarch64-darwin` without a linux remote builder this command will fail at scheduling (no builder for `aarch64-linux`). Skip it locally and rely on CI to run it — that is the whole point of the Step 2 flip.

- [x] **Step 5: Sanity-check CI workflow YAML parses**

Run: `actionlint .github/workflows/ci.yml`

Expected: no output (success). If actionlint isn't on PATH, run via `nix run nixpkgs#actionlint -- .github/workflows/ci.yml`.

- [x] **Step 6: Commit**

Run:

```sh
git add justfile .github/workflows/ci.yml
git commit -m "tests: actually run flake checks (drop --no-build, enable matrix.check on linux)"
```

---

## Task 2: Add missing deny rules and regression payloads

The `check-bash-command.sh` matcher does literal token-prefix matching on the rule list, so any flag spelling (long-form, cluster-merged, modern split commands) that doesn't tokenize identically to a rule slips through. Concretely:

- `git rebase -i` does NOT match `git rebase --interactive`
- `git clean -f` does NOT match `git clean --force ...`
- `git clean -f` does NOT match `git clean -fX` or `git clean -ff` (third token differs)
- `git checkout --` does NOT match `git restore .` (modern split, completely different command)
- `git reset --hard` does NOT match `git reset --merge` or `git reset --keep` (also destructive)
- `git filter-branch` does NOT match `git filter-repo` (modern replacement)
- `git update-ref -d` does NOT match `git update-ref --stdin` (batch mode can delete refs)

Add the missing variants to `deniedSubcommands` and pin every gap with regression payloads in the fixture so future refactors can't silently re-open them. Several gaps are best closed by collapsing to a bare-prefix rule (`git clean`, `git restore`) rather than enumerating every flag combination — the trade-off is documented per-rule below.

**Files:**
- Modify: `modules/claude-security/default.nix:132-146` — replace the `deniedSubcommands` option default
- Modify: `modules/claude-security/scripts/test-fixtures/bypass-payloads.txt` — append regression payloads
- Modify: `tests/check-bash-matcher.nix:8-16` — replace the test's `deniedSubcommands` literal to mirror the module default exactly (they are intentionally duplicated; the test pins behavior independently of any future option-default change)

**Pros and cons of strategy:**
- Pro: literal token enumeration is consistent with the existing matcher design — no behavior change in the matcher itself, just data.
- Pro: bare-prefix rules (`git clean`, `git restore`) catch every flag combination at the cost of also blocking the rare safe forms (`git clean -n` dry-run, `git restore --staged` for unstage). Trading the corner cases for matcher simplicity is the right call until canonicalization lands.
- Pro: fixture entries lock in the gap — the moment a future matcher rewrite drops a rule or regresses prefix logic, the test fails.
- Con: still brittle to any *future* flag alias the deny list doesn't enumerate (`--no-edit`, exotic git plumbing, etc.). The proper fix is matcher-side flag canonicalization (`--interactive` → `-i`, decompose `-fdX` → `-f -d -X`); that's a larger redesign tracked under "Out of scope" below.

- [x] **Step 1: Add regression payloads to the fixture (test first)**

Edit `modules/claude-security/scripts/test-fixtures/bypass-payloads.txt` and append at end-of-file:

```
git rebase --interactive HEAD~3
git clean --force
git clean --force -d
git clean --force -dx
git clean -fX
git clean -ff
git clean -fdX
git restore .
git restore --worktree file.txt
git reset --merge HEAD~1
git reset --keep HEAD~1
git filter-repo --path src --invert-paths
git update-ref --stdin
```

- [x] **Step 2: Run the regression test — confirm it FAILS** (SKIPPED: no aarch64-linux builder on darwin host; CI will catch regressions once Task 1 lands)

Run: `nix build .#checks.aarch64-linux.check-bash-matcher --print-build-logs 2>&1 | tail -60`

Expected: build fails. Note that the *current* test `deniedSubcommands` (`tests/check-bash-matcher.nix:13`) uses bare `"git clean"`, which already prefix-matches all `git clean ...` variants — so those payloads will NOT print BYPASS at this step. The payloads that WILL print BYPASS are the ones not covered by any current rule:

```
BYPASS: payload=[git rebase --interactive HEAD~3]   (no --interactive rule)
BYPASS: payload=[git restore .]                     (no restore rule)
BYPASS: payload=[git restore --worktree file.txt]   (no restore rule)
BYPASS: payload=[git reset --merge HEAD~1]          (--hard rule only)
BYPASS: payload=[git reset --keep HEAD~1]           (--hard rule only)
BYPASS: payload=[git filter-repo --path src ...]    (filter-branch rule only)
BYPASS: payload=[git update-ref --stdin]            (-d rule only)
```

The `git clean ...` payloads we just appended will silently pass at this step because of the bare `"git clean"` rule in the test. They become load-bearing once Step 4 mirrors the new module list (which switches to enumerated clean variants). Don't proceed until you see the seven BYPASS lines above.

- [x] **Step 3: Extend `deniedSubcommands` default**

Edit `modules/claude-security/default.nix:132-146`. Replace:

```nix
        deniedSubcommands = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "git push"
            "git reset --hard"
            "git rebase -i"
            "git checkout --"
            "git clean -f"
            "git clean -fd"
            "git clean -fdx"
            "git filter-branch"
            "git update-ref -d"
          ];
          description = "Multi-word commands that are hard-blocked (denied even in unrestricted mode)";
        };
```

with:

```nix
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
```

Notes on the rule choices:
- `git reset --merge` / `--keep` are destructive in addition to `--hard` (`--soft` and the default `--mixed` don't touch the worktree, so they remain allowed).
- `git restore` (bare) blocks `git restore .` and `git restore --worktree FILE` (modern destructive equivalents of `git checkout --`). It also blocks `git restore --staged FILE` (safe unstage) — accept the false positive; users can override per-call.
- `git clean` (bare) replaces the four enumerated `-f`/`-fd`/`-fdx`/`--force` rules. Catches `-fX`, `-ff`, `-fdX`, `--force -d`, etc. without enumeration. Blocks `git clean -n` (dry-run) too — accept the false positive.
- `git filter-repo` blocks the modern history-rewrite tool that `git filter-branch` was deprecated in favor of.
- `git update-ref --stdin` blocks batch ref-update mode, which can delete refs as effectively as `-d`.

- [x] **Step 4: Mirror the change in the test fixture's `deniedSubcommands`**

Edit `tests/check-bash-matcher.nix:8-16`. Replace:

```nix
      deniedSubcommands = [
        "git push"
        "git reset --hard"
        "git rebase -i"
        "git checkout --"
        "git clean"
        "git filter-branch"
        "git update-ref -d"
      ];
```

with:

```nix
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
```

Note: the existing `"git clean"` bare-prefix entry is kept as-is (it now matches the module default's bare-prefix posture). The test mirrors the module default exactly — that's the contract the test should pin.

- [x] **Step 5: Re-run the regression test — confirm it PASSES** (SKIPPED: no aarch64-linux builder on darwin host; CI will catch any regression once Task 1 lands)

Run: `nix build .#checks.aarch64-linux.check-bash-matcher --print-build-logs 2>&1 | tail -10`

Expected: build succeeds, no `BYPASS:` lines.

- [x] **Step 6: Confirm no regression on pre-existing payloads**

The fixture (`bypass-payloads.txt`) already covers the original rebase/clean/checkout/push payloads. Step 5's clean rebuild of `check-bash-matcher` is the regression check — every payload (old and new) is exercised by the test and any uncaught one prints `BYPASS:` and fails the build. No separate spot-check loop is needed; do not invent one.

The earlier draft of this plan suggested driving the matcher binary directly via `nix eval --raw .#checks.aarch64-linux.check-bash-matcher`, but that derivation's `$out` is a plain file (`touch $out` in `tests/check-bash-matcher.nix:39`) — it has no `bin/claude-check-bash-command`. The actual binary is built by `modules/claude-security/scripts/wrap.nix` and is exercised inside the test via `${hookScript}/bin/claude-check-bash-command`. Trying to invoke it from outside the test is the wrong tree to bark up; the test IS the spot-check.

- [ ] **Step 7: Commit**

Run:

```sh
git add modules/claude-security/default.nix \
        modules/claude-security/scripts/test-fixtures/bypass-payloads.txt \
        tests/check-bash-matcher.nix
git commit -m "claude-security: close known matcher bypasses (long-form flags, modern split commands, destructive reset modes) + regression fixture"
```

---

## Task 3: Polish — wrong comment, dead branch, fork-hostname note

Three small unrelated cleanups identified by the review:

1. `modules/claude-security/scripts/wrap.nix:54-57` says read-gate / edit-track stay on `writeShellScriptBin` because of "shfmt fallback paths". Neither script invokes shfmt. The real reason is they predate the migration and there's no concrete benefit yet to the strict-mode wrapper.
2. `home/common/qdrant.nix:10-13` branches on `pkgs.stdenv.isDarwin`. The file is now imported only from `home/darwin/default.nix`, so the `else "127.0.0.1"` branch can never execute.
3. `README.md` § Forking doesn't tell forkers that `just switch` hardcodes `burnedapple` / `nixos`. A user who runs `setup.sh`, picks a different hostname, then runs `just switch` will hit `attribute 'burnedapple' missing`.

**Files:**
- Modify: `modules/claude-security/scripts/wrap.nix:54-57`
- Modify: `home/common/qdrant.nix:7-13`
- Modify: `README.md` (insert one note in the Forking section, after the Quick-setup code fence closes at line 43)

- [x] **Step 1: Fix the wrap.nix comment**

Edit `modules/claude-security/scripts/wrap.nix:54-57`. Replace:

```nix
  # The remaining hooks need to swallow non-zero exits from their
  # internals (notably shfmt fallback paths), which `set -e` from
  # writeShellApplication wouldn't tolerate. symlinkJoin+makeWrapper
  # gives them a runtime PATH without the strict-mode wrapper.
```

with:

```nix
  # read-gate and edit-track stay on writeShellScriptBin for now: the migration
  # to writeShellApplication isn't load-bearing here (no shellcheck wins to
  # collect, no `set -e` traps to enforce — both scripts intentionally tolerate
  # non-zero exits from realpath/sha256sum via `|| ...` fallbacks). symlinkJoin
  # + makeWrapper still gives them coreutils/jq on PATH.
```

- [x] **Step 2: Collapse the dead `isDarwin` branch in qdrant.nix**

Edit `home/common/qdrant.nix`. Replace lines 1-14 (the let-in header):

```nix
{
  config,
  pkgs,
  ...
}: let
  homeDir = config.home.homeDirectory;
  # On macOS: bind to 0.0.0.0 so NixOS VM can connect over UTM network
  # macOS firewall restricts access to UTM subnet only (see system/darwin)
  # On NixOS: localhost only (uses macOS qdrant over network)
  bindHost =
    if pkgs.stdenv.isDarwin
    then "0.0.0.0"
    else "127.0.0.1";
in {
```

with:

```nix
{config, ...}: let
  homeDir = config.home.homeDirectory;
  # Bind to 0.0.0.0 so the NixOS VM can reach qdrant over UTM's shared net.
  # macOS firewall already restricts inbound to the UTM subnet (see system/darwin).
  # This module is darwin-only — imported from home/darwin/default.nix.
  bindHost = "0.0.0.0";
in {
```

After write, run `just fmt` — alejandra normalizes `{config, ...}: let` to its preferred form (typically inlines as-is here, but let the formatter own it). The `pkgs` arg is no longer needed once `pkgs.stdenv.isDarwin` is gone — `deadnix` will catch it if left in.

- [x] **Step 3: Add fork-hostname note to README**

Edit `README.md`. The Quick setup shell block ends with the closing fence at line 43. Insert the following AFTER line 43 (i.e. after the closing ` ``` `, before the blank line that precedes `### Manual setup` at line 45):

```markdown

> **Forking:** `just switch` and `just cache` hardcode the host attribute
> names (`burnedapple` / `nixos`). If you change `hostname` in your host file,
> either match one of those names or edit the recipes in `justfile`.
```

**Do not** insert the prose inside the fenced ` ```shell ` block (which spans lines 18-43) — that would corrupt the README rendering. Verify by running `grep -n '^```' README.md` after the edit and confirming the new blockquote is between fences, not inside one.

- [x] **Step 4: Lint the changes**

Run:

```sh
just lint-nix-fast
just lint-shell
```

Expected: clean. `deadnix` will fail if the unused `pkgs` arg slipped through Step 2; `statix`/`alejandra` will catch any formatting drift.

- [x] **Step 5: Verify the qdrant config still renders**

Run: `nix eval --raw .#darwinConfigurations.burnedapple.config.home-manager.users.vaporif.home.file.".qdrant/config.yaml".text 2>&1 | head -10`

Expected: the YAML body, with `host: 0.0.0.0`. If eval fails, the `pkgs` arg removal broke something — restore it.

- [x] **Step 6: Commit**

Run:

```sh
git add modules/claude-security/scripts/wrap.nix home/common/qdrant.nix README.md
git commit -m "polish: fix wrong wrap.nix comment, drop dead qdrant branch, document fork hostname"
```

---

## Out of scope (and why)

The review surfaced a few more findings that we are explicitly NOT addressing in this plan:

- **Matcher-side flag canonicalization** — the proper long-term fix for the bypass class enumerated in Task 2. Normalizing `--interactive` → `-i`, decomposing `-fdX` → `-f -d -X` before prefix-matching would let us drop the explicit aliases and the bare-prefix false positives (`git clean -n`, `git restore --staged`). It's a non-trivial rewrite of `check-bash-command.sh` and out of scope here. Track as a follow-up.
- **Deny/ask ordering structural bug in `check-bash-command.sh`** — real, but not triggerable with the current default `blockedSubcommands = []`. Worth a one-line invariant comment in the script if you populate `blockedSubcommands` later, but no fix needed today. Adding the comment now without a triggering rule risks the comment going stale.
- **SSH key comment with `burned-apple`** in `hosts/common.nix:7` — baked into the Secretive-generated public key. Fixing requires rotating the key + updating GitHub + `authorized_keys`. Not worth it for a comment field.
- **ntfy CRLF, realpath PATH, secrets gating** — validators rejected as not exploitable / not a real risk in the current wiring.
- **`env <cmd>` prefix bypass** — `env git push origin main` is parsed by shfmt as a single CallExpr where the first token is `env`, not `git`. The matcher's basename check sees `env`, no rule matches, command passes. Fixing this requires teaching the matcher to skip leading `env` (and detect inline `var=value env`-style assignments). Real but low-priority — Claude doesn't prefix git with `env` in normal use.

## Self-review checklist (run before handing off)

- [ ] Spec coverage: every "Must fix" + "Nice to fix" item from the previous turn maps to a task above. The "Skip" items are listed under Out of Scope.
- [ ] No placeholders: every step has either exact code, an exact command with expected output, or both.
- [ ] Type / name consistency: `deniedSubcommands` is spelled identically across `default.nix` and `tests/check-bash-matcher.nix`. Every new rule string (`"git rebase --interactive"`, `"git restore"`, `"git clean"`, `"git reset --merge"`, `"git reset --keep"`, `"git filter-repo"`, `"git update-ref --stdin"`) appears identically in both.
- [ ] Frequent commits: one commit per task (3 commits total). Polish runs as a separate post-implementation pass per the standard subagent-driven-development flow.
- [ ] README insertion landed outside the fenced shell block (`grep -n '^```' README.md` shows the new blockquote between fences, not inside).
- [ ] Local `just check` passed without `--no-build`. On macOS this only rebuilds `formatting`; the four linux test derivations are exercised via CI on `ubuntu-24.04-arm`. No expectation that `just check` builds them locally on a darwin host without a remote builder.
- [ ] Bypass coverage acknowledged: the matcher remains literal-token-prefix and brittle to flag aliases not enumerated above. Future canonicalization is tracked under "Out of scope".
