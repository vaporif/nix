-- snacks.nvim is loaded eagerly by Nix
require('snacks').setup {
  bigfile = { enabled = true },
  image = { enabled = false },
  input = {},
  notifier = { enabled = true },
  picker = {
    ui_select = true,
  },
}

vim.keymap.set('n', '<leader>g', function()
  require('snacks').lazygit()
end, { desc = 'Lazy[g]it' })

vim.keymap.set('n', '<leader>l', function()
  require('snacks').lazygit.log()
end, { desc = 'git [l]ogs' })

vim.keymap.set('n', '<leader>D', function()
  require('snacks').terminal 'gh dash'
end, { desc = 'gh [D]ash' })
