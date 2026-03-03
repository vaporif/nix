---
globs: "**/*.nix"
---

# Nix

- Prefer `lib.mkIf` over `if/then` for conditional module options
- Use `lib.optionalAttrs`, `lib.optionals`, `lib.optionalString` over `if/then/else` for attribute sets, lists, strings
- Prefer explicit `lib.` prefixed calls over `with lib;` — `with` pollutes scope and hides where names come from
- Use `rec` sparingly — prefer `let ... in` for local bindings
- Destructure function args: `{ lib, pkgs, config, ... }:` — only include what you use
- `deadnix` flags unused params — strip them rather than prefixing with `_`
- Group related attrs together rather than scattering them (e.g. all `boot.*` in one block)
- Use `mkDefault` for overridable defaults, `mkForce` only when necessary
- Pin flake inputs; avoid `follows` chains deeper than one level
- Prefer `callPackage` pattern for package definitions — it enables override/overlay composition
- Use `builtins.readFile` for static content, `pkgs.writeText` for generated content
- Prefer `lib.getExe pkg` over `"${pkg}/bin/name"` for referencing executables
- Multiline strings: use `''` (double single-quote) — avoid `\n` escapes
- Prefer `pkgs.fetchurl` with `hash` over `builtins.fetchurl` — the latter has no hash verification

## Toolchain

- Formatter: `alejandra` — run before commit
- Linter: `statix` — catches anti-patterns (e.g. manual `if` instead of `lib.mkIf`)
- Dead code: `deadnix` — remove unused bindings, don't underscore-prefix them
- LSP: `nixd` — configure `nixd.options` for nix-darwin and home-manager completions
- All code must pass `nix flake check` in pure eval mode — no impure references (`/etc/`, absolute paths outside store)
