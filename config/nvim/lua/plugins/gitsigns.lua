require('lze').load {
  {
    'gitsigns.nvim',
    event = 'BufReadPre',
    after = function()
      require('gitsigns').setup {
        signs = {
          add = { text = '󰌪' },
          change = { text = '' },
          delete = { text = '󱋙' },
          topdelete = { text = '' },
          changedelete = { text = '󰬳' },
          untracked = { text = '󰹦' },
        },
        on_attach = function(bufnr)
          local gitsigns = require 'gitsigns'

          local function map(mode, l, r, opts)
            opts = opts or {}
            opts.buffer = bufnr
            vim.keymap.set(mode, l, r, opts)
          end

          map('n', ']g', function()
            if vim.wo.diff then
              vim.cmd.normal { ']c', bang = true }
            else
              gitsigns.nav_hunk 'next'
            end
          end, { desc = 'next [g]it hunk' })

          map('n', '[g', function()
            if vim.wo.diff then
              vim.cmd.normal { '[c', bang = true }
            else
              gitsigns.nav_hunk 'prev'
            end
          end, { desc = 'prev [g]it hunk' })
          map('v', '<leader>hs', function()
            gitsigns.stage_hunk { vim.fn.line '.', vim.fn.line 'v' }
          end, { desc = 'stage git hunk' })
          map('v', '<leader>hr', function()
            gitsigns.reset_hunk { vim.fn.line '.', vim.fn.line 'v' }
          end, { desc = 'reset git hunk' })
          map('n', '<leader>hs', gitsigns.stage_hunk, { desc = '[s]tage hunk' })
          map('n', '<leader>hr', gitsigns.reset_hunk, { desc = '[r]eset hunk' })
          map('n', '<leader>hS', gitsigns.stage_buffer, { desc = '[S]tage buffer' })
          map('n', '<leader>hR', gitsigns.reset_buffer, { desc = '[R]eset buffer' })
          map('n', '<leader>hp', gitsigns.preview_hunk, { desc = '[p]review hunk' })
          map('n', '<leader>hb', gitsigns.blame_line, { desc = '[b]lame line' })
          map('n', '<leader>hd', gitsigns.diffthis, { desc = '[d]iff against index' })
          map('n', '<leader>hD', function()
            gitsigns.diffthis '@'
          end, { desc = '[D]iff against last commit' })
          map('n', '<leader>hB', gitsigns.toggle_current_line_blame, { desc = 'toggle [B]lame' })
          map('n', '<leader>hi', gitsigns.preview_hunk_inline, { desc = 'preview [i]nline' })
          map('n', '<leader>hh', function()
            gitsigns.setqflist 'all'
          end, { desc = 'file [h]istory' })
        end,
      }
    end,
  },
}
