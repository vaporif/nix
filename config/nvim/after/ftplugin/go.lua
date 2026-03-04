vim.opt_local.makeprg = 'go build ./...'
vim.keymap.set('n', '<leader>cb', '<cmd>make<CR>', { buffer = 0, desc = '[b]uild' })
vim.keymap.set('n', '<leader>cr', '<cmd>!go run .<CR>', { buffer = 0, desc = '[r]un' })
vim.keymap.set('n', '<leader>cm', '<cmd>!go mod tidy<CR>', { buffer = 0, desc = '[m]od tidy' })

vim.keymap.set('n', '<leader>ce', '<cmd>GoIfErr<CR>', { buffer = 0, desc = 'if [e]rr' })
vim.keymap.set('n', '<leader>ci', '<cmd>GoImpl<CR>', { buffer = 0, desc = '[i]mplement interface' })
vim.keymap.set('n', '<leader>ct', '<cmd>GoAddTag<CR>', { buffer = 0, desc = '+struct [t]ags' })
vim.keymap.set('n', '<leader>cg', '<cmd>GoRmTag<CR>', { buffer = 0, desc = '-struct ta[g]s' })
vim.keymap.set('n', '<leader>cf', '<cmd>GoFillStruct<CR>', { buffer = 0, desc = '[f]ill struct' })
