-- Vim's bundled Python indent (runtime/indent/python.vim) defaults to
-- `shiftwidth() * 2` for lines opened inside brackets and for
-- backslash-continuations. Override to a single shiftwidth so `o` after
-- `[`, `(`, `{` produces 4 spaces of hang, not 8.
vim.g.python_indent = {
  open_paren = 'shiftwidth()',
  nested_paren = 'shiftwidth()',
  continue = 'shiftwidth()',
  closed_paren_align_last_line = false,
  searchpair_timeout = 150,
}
