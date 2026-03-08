-- Diagnostics
vim.keymap.set('n', '[d', function()
  vim.diagnostic.jump { count = -1, float = true }
end, { desc = 'Prev diagnostic' })
vim.keymap.set('n', ']d', function()
  vim.diagnostic.jump { count = 1, float = true }
end, { desc = 'Next diagnostic' })
vim.keymap.set('n', '[e', function()
  vim.diagnostic.jump { count = -1, float = true, severity = vim.diagnostic.severity.ERROR }
end, { desc = 'Prev error' })
vim.keymap.set('n', ']e', function()
  vim.diagnostic.jump { count = 1, float = true, severity = vim.diagnostic.severity.ERROR }
end, { desc = 'Next error' })

-- Code (generic)
vim.keymap.set('n', '<leader>cd', '<cmd>Difft<CR>', { desc = '[d]iff unstaged' })
vim.keymap.set('n', '<leader>cs', '<cmd>Difft --staged<CR>', { desc = 'diff [s]taged' })
vim.keymap.set('n', '<leader>cF', '<cmd>DiffviewFileHistory<CR>', { desc = '[F]ilehistory' })

vim.keymap.set('n', '<leader>/', 'gcc', { desc = 'toggle comment', remap = true })
vim.keymap.set('v', '<leader>/', 'gc', { desc = 'toggle comment', remap = true })
vim.keymap.set('n', '<leader>w', '<cmd>w!<CR>', { desc = '[w]rite' })
vim.keymap.set('n', '<leader>e', '<cmd>Neotree float toggle reveal_force_cwd<CR>', { desc = 'n[e]otree' })

vim.keymap.set('n', '<leader><Tab>', '<C-w>w', { desc = 'next pane' })

vim.keymap.set('n', '<leader>sv', '<cmd>vsplit<CR>', { desc = '[v]ertically' })
vim.keymap.set('n', '<leader>sh', '<cmd>split<CR>', { desc = '[h]orizontally' })

-- Buffer navigation
vim.keymap.set('n', '<S-h>', '<cmd>bprevious<CR>', { desc = 'Prev buffer' })
vim.keymap.set('n', '<S-l>', '<cmd>bnext<CR>', { desc = 'Next buffer' })
vim.keymap.set('n', '<leader>bp', '<cmd>bprevious<CR>', { desc = '[p]revious' })
vim.keymap.set('n', '<leader>bn', '<cmd>bnext<CR>', { desc = '[n]ext' })
vim.keymap.set('n', '<leader>bd', '<cmd>bdelete<CR>', { desc = '[d]elete' })
vim.keymap.set('n', '<leader>bo', '<cmd>%bdelete|edit#|bdelete#<CR>', { desc = '[o]nly (close others)' })

vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>', { desc = 'Clear search highlight' })
vim.keymap.set('i', 'ii', '<Esc>')

-- Unbind hj since I use extend layer & colemak (l is used by Flash, k is used by Flash Treesitter)
vim.keymap.set({ 'n', 'v', 'o' }, 'h', '<Nop>')
vim.keymap.set({ 'n', 'v', 'o' }, 'j', '<Nop>')
vim.keymap.set({ 'n', 'v', 'o' }, 'k', '<Nop>')
vim.keymap.set({ 'n', 'v', 'o' }, 'l', '<Nop>')

-- ; -> :
vim.keymap.set({ 'n', 'x' }, ';', ':')

-- disable macros fully
vim.keymap.set({ 'n', 'x' }, 'q', function() end)
vim.keymap.set({ 'n', 'x' }, 'Q', function() end)

-- delete default code operations
for _, key in ipairs { 'grn', 'grr', 'gri', 'gra' } do
  pcall(vim.keymap.del, 'n', key)
end
