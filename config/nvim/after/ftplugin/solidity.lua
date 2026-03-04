vim.opt_local.makeprg = 'forge build'
vim.keymap.set('n', '<leader>cb', '<cmd>make<CR>', { buffer = 0, desc = '[b]uild' })
vim.keymap.set('n', '<leader>cG', '<cmd>!forge snapshot<CR>', { buffer = 0, desc = '[G]as snapshot' })
vim.keymap.set('n', '<leader>cc', '<cmd>!forge coverage<CR>', { buffer = 0, desc = '[c]overage' })
vim.keymap.set('n', '<leader>cf', '<cmd>!forge fmt<CR>', { buffer = 0, desc = '[f]ormat' })
vim.keymap.set('n', '<leader>ci', '<cmd>!forge install<CR>', { buffer = 0, desc = '[i]nstall deps' })
vim.keymap.set('n', '<leader>cu', '<cmd>!forge update<CR>', { buffer = 0, desc = '[u]pdate deps' })
vim.keymap.set('n', '<leader>cx', '<cmd>!forge clean<CR>', { buffer = 0, desc = 'clean' })
