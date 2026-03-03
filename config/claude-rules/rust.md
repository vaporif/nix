---
globs: "**/*.rs"
---

# Rust

- Modern module syntax: `foo.rs` + `foo/bar.rs` — never `foo/mod.rs`
- `thiserror` for library error types, `anyhow` for application error handling
- No `.unwrap()` or `.expect()` in production code — propagate with `?` or handle explicitly
- Prefer `&str` over `&String` in function parameters — more general, zero-cost
- Prefer `impl Trait` in function args/returns over concrete types or `Box<dyn Trait>` where possible
- Use `#[must_use]` on functions where ignoring the return value is likely a bug
- Derive `Debug` on all public types; derive `Clone`, `PartialEq` when semantically appropriate
- Prefer iterators and combinators (`.map`, `.filter`, `.collect`) over manual loops
- Enable `clippy::pedantic` and `clippy::nursery` — suppress individual noisy lints with `#[allow]` and justification
- Constructors: `Type::new()` for simple cases, builder pattern for 3+ optional fields
- Prefer `Vec<T>` over `&[T]` in struct fields that own data; `&[T]` in function params
- Prefer `String` or `&str` — only reach for `Cow<'_, str>` when profiling shows allocation is a bottleneck
- Group imports: `std` → external crates → `crate::` — one `use` block per group
- Unsafe: isolate in minimal blocks, document invariants, prefer safe abstractions

## Toolchain

- `cargo fmt` is non-negotiable — all code must be formatted before commit
- `cargo deny` for dependency auditing — check licenses and known vulnerabilities in CI
- `#![deny(warnings)]` in CI builds — zero warnings policy
- Use `rust-analyzer` as LSP

## Security

- Validate all input at system boundaries (user input, API responses, file reads) — trust nothing from outside
- Use parameterized queries with `sqlx`/`diesel` — never format SQL strings with `format!`
- Use `subtle::ConstantTimeEq` for secret/token comparison — never `==` (timing side-channel)
- Never disable TLS verification (`danger_accept_invalid_certs`) outside of tests
