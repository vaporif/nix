require('lze').load {
  {
    'grug-far.nvim',
    cmd = 'GrugFar',
    keys = {
      {
        '<leader>qg',
        function()
          local ext = vim.bo.buftype == '' and vim.fn.expand '%:e'
          require('grug-far').open {
            transient = true,
            prefills = { filesFilter = ext and ext ~= '' and '*.' .. ext or nil },
          }
        end,
        mode = { 'n', 'v' },
        desc = '[g]lobal',
      },
      {
        '<leader>qw',
        function()
          local grug = require 'grug-far'
          if vim.fn.mode():match '[vV]' then
            grug.with_visual_selection()
          else
            local buf_name = vim.api.nvim_buf_get_name(0)
            grug.open { transient = true, prefills = { paths = buf_name ~= '' and buf_name or nil } }
          end
        end,
        mode = { 'n', 'v' },
        desc = '[w]ithin buffer/selection',
      },
    },
    after = function()
      require('grug-far').setup {}
      vim.api.nvim_create_autocmd('FileType', {
        pattern = 'grug-far',
        callback = function()
          vim.keymap.set({ 'i', 'n' }, '<Esc>', '<Cmd>stopinsert | bd!<CR>', { buffer = true })
        end,
      })
    end,
  },
}
