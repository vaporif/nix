---
globs: "**/*.go"
---

# Go

- Accept interfaces, return structs — keeps APIs flexible and concrete
- Wrap errors with context: `fmt.Errorf("doing X: %w", err)` — never bare `return err`
- `context.Context` is always the first parameter, named `ctx`
- Table-driven tests with `t.Run` subtests — name each case descriptively
- Avoid `init()` for business logic — acceptable only for driver/codec registration (e.g. `_ "github.com/lib/pq"`)
- Short variable names in small scopes (`i`, `n`, `err`), descriptive names in larger scopes
- No naked returns — always explicitly return values
- Prefer `errors.Is` / `errors.As` over `==` for error comparison
- Use `sync.Once` for lazy initialization, not `init()` or manual mutex patterns
- Prefer `io.Reader` / `io.Writer` interfaces over concrete types in function params
- Channel direction in signatures: `chan<-` for send-only, `<-chan` for receive-only
- Goroutines: always have a clear shutdown path — use `context.WithCancel` or `done` channel
- Prefer `slices` and `maps` packages (Go 1.21+) over hand-rolled helpers
- Use `slog` (Go 1.21+) for structured logging — not `log` or `fmt.Println`
- Embed interfaces only when the struct genuinely satisfies the full contract
- Functional options pattern for configurable constructors: `type Option func(*Server)`
- Always pass `context.Context` with timeouts/deadlines to external calls (HTTP, DB, gRPC)
- Keep interfaces small: 1–3 methods. Define at the consumer, not the implementer

## Toolchain

- `gofmt` + `goimports` are non-negotiable — all code must be formatted before commit
- `go test -race ./...` — always run with race detector
- `golangci-lint run` with `gosec` enabled — prefer over standalone `gosec`

## Security

- Use parameterized queries (`db.Query("SELECT * FROM x WHERE id = $1", id)`) — never `fmt.Sprintf` SQL
- Use `exec.Command(bin, args...)` with separate args — never `exec.Command("sh", "-c", userInput)`
- Use `html/template` for HTML output — `text/template` does not escape and enables XSS
- Use `crypto/subtle.ConstantTimeCompare` for secret/token comparison — never `==` (timing side-channel)
- Set `tls.Config{MinVersion: tls.VersionTLS12}` — never allow TLS 1.0/1.1
