-- Library/dependency plugins loaded on require via lze
-- These sit in opt/ and are loaded when their modules are first required
require('lze').load {
  { 'plenary.nvim', on_require = { 'plenary', 'luassert', 'say' } },
  { 'nvim-nio', on_require = 'nio' },
  { 'nui.nvim', on_require = 'nui' },
  { 'nvim-web-devicons', on_require = 'nvim-web-devicons' },
  { 'promise-async', on_require = { 'promise', 'async' } },
  { 'guihua.lua', on_require = { 'guihua', 'fzy' } },
  { 'nvim-dap-ui', on_require = 'dapui' },
  { 'nvim-dap-go', on_require = 'dap-go' },
  { 'nvim-treesitter-textobjects', on_require = 'nvim-treesitter-textobjects' },
  { 'neotest-golang', dep_of = 'neotest' },
  { 'neotest-python', dep_of = 'neotest' },
  { 'neotest-vitest', dep_of = 'neotest' },
  { 'neotest-foundry', dep_of = 'neotest' },
}
