---
globs: "**/*.lua"
---

# Lua

- Always use `local` — never pollute the global namespace
- Module pattern: define a local table, attach functions, `return` it at the end
- Prefer `string.format()` over `..` concatenation for complex strings
- Use `vim.keymap.set` over `vim.api.nvim_set_keymap` in Neovim configs
- Prefer `vim.opt` over `vim.o`/`vim.wo`/`vim.bo` — it handles list/map options correctly
- Use `vim.tbl_deep_extend("force", defaults, overrides)` for merging config tables
- Check nil explicitly: `if x ~= nil` — Lua treats `false` and `nil` differently
- Prefer `ipairs` for arrays (sequential integer keys), `pairs` for hash tables
- Avoid `:gsub` with raw user input as pattern — `%` is the escape char, not `\`
- Keep requires at the top of the file
- Use early returns to reduce nesting
- Selene is the linter, stylua is the formatter — run both before commit
- Prefer lazy-loading plugins with `vim.lazy` or conditional `require` — startup time matters in Neovim
- Avoid `vim.cmd` for things that have Lua API equivalents — prefer native Lua APIs

## Security

- Never pass untrusted input to `loadstring`/`load`/`dofile` — direct code injection
- Never pass unsanitized input to `os.execute` or `io.popen` — shell command injection
