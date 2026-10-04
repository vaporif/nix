---
globs: "**/*.rs"
---

# Rust

- `thiserror` for library error types, `anyhow` for application error handling
- Prefer `impl Trait` in function args/returns over concrete types or `Box<dyn Trait>` where possible
- Derive `Debug` on all public types; derive `Clone`, `PartialEq` when semantically appropriate
- Prefer iterators and combinators (`.map`, `.filter`, `.collect`) over manual loops
- Enable `clippy::pedantic` and `clippy::nursery` — suppress individual noisy lints with `#[allow]` and justification
- Constructors: `Type::new()` for simple cases, builder pattern for 3+ optional fields
- Prefer `Vec<T>` over `&[T]` in struct fields that own data; `&[T]` in function params
- Prefer `String` or `&str` — only reach for `Cow<'_, str>` when profiling shows allocation is a bottleneck
- Group imports: `std` → external crates → `crate::` — one `use` block per group
- Unsafe: isolate in minimal blocks, document invariants, prefer safe abstractions

## Concurrency

- Prefer `tokio::task::JoinSet` or `futures::stream::FuturesUnordered` for concurrent work over sequential `.await` loops
- Use `Stream` + `StreamExt::buffer_unordered(n)` for bounded parallel processing of iterators
- Prefer `tokio::sync::mpsc` for work distribution, `broadcast` for fan-out
- Use `tokio::select!` for racing futures — always handle all branches
- Shared state: prefer message passing over `Arc<Mutex<T>>`; when mutex is needed, minimize critical sections
- CPU-bound work goes on `tokio::task::spawn_blocking` — never block the async runtime

## Performance

- Use `Vec::with_capacity(n)` when size is known — avoids reallocations
- Prefer `Box<str>` / `Arc<str>` over `String` for immutable shared strings
- Use `rayon` for CPU-bound parallelism — `.par_iter()` is a drop-in replacement for `.iter()`
- Prefer `bytes::Bytes` over `Vec<u8>` for zero-copy buffer sharing
- Use `SmallVec` or `tinyvec` for small, stack-allocated collections that rarely exceed N elements
- Profile before optimizing — `cargo flamegraph` or `criterion` for benchmarks, not guesswork

## Toolchain

- `cargo fmt` is non-negotiable — all code must be formatted before commit
- `cargo deny` for dependency auditing — check licenses and known vulnerabilities in CI
- `#![deny(warnings)]` in CI builds — zero warnings policy
- Use `rust-analyzer` as LSP

## Build cache (sccache)

sccache is opt-in per project, wired up in the project's own `flake.nix` devShell. The machine already sets `SCCACHE_DIR=~/.cache/sccache`, shared by the host shell and the agent sandboxes.

- Hook it up by adding `pkgs.sccache` to the devShell `packages` and setting `RUSTC_WRAPPER = "sccache";` on the devShell — nothing else
- Never set `SCCACHE_DIR` in a project — the sandbox can only write `~/.cache/sccache`, any other path breaks sandboxed builds
- Never set `SCCACHE_SERVER_UDS` / `SCCACHE_SERVER_PORT` — each sandbox runs its own sccache server on a private socket so compiles never run outside the sandbox; overriding it can attach to the host's server
- Don't put `rustc-wrapper` in `.cargo/config.toml` — it breaks builds for anyone without sccache; keep it in the devShell
- Verify with `sccache --show-stats` after a build; workspace crates in incremental (dev) builds are never cached, only dependencies and release builds

## Security

- Validate all input at system boundaries (user input, API responses, file reads) — trust nothing from outside
- Use `subtle::ConstantTimeEq` for secret/token comparison — never `==` (timing side-channel)
- Never disable TLS verification (`danger_accept_invalid_certs`) outside of tests
