require('lze').load {
  {
    'fzf-lua',
    keys = {
      { '<leader>fh', '<cmd>FzfLua help_tags<cr>', desc = '[h]elp' },
      { '<leader>fk', '<cmd>FzfLua keymaps<cr>', desc = '[k]eymaps' },
      { '<leader>ff', '<cmd>FzfLua files<cr>', desc = '[f]iles' },
      { '<leader>fz', '<cmd>FzfLua builtin<cr>', desc = 'f[z]f' },
      { '<leader>fg', '<cmd>FzfLua live_grep<cr>', desc = '[g]rep' },
      { '<leader>fd', '<cmd>FzfLua diagnostics_document<cr>', desc = '[d]ocument diagnostics' },
      { '<leader>fr', '<cmd>FzfLua resume<cr>', desc = '[r]esume' },
      { "'", '<cmd>FzfLua marks<cr>', mode = { 'n', 'v' }, desc = 'Marks' },
      { '<leader>fb', '<cmd>FzfLua buffers<cr>', desc = '[b]uffers' },
      { '<leader>fc', '<cmd>FzfLua git_bcommits<cr>', desc = 'buffer [c]ommits' },
      { '<leader>fm', '<cmd>Noice fzf<cr>', desc = '[m]essages' },
      { 'gd', '<cmd>FzfLua lsp_definitions<cr>', desc = 'goto [d]efinition' },
      { 'gR', '<cmd>FzfLua lsp_references<cr>', desc = 'goto [R]eferences (fzf-lua)' },
      { 'gI', '<cmd>FzfLua lsp_implementations<cr>', desc = 'goto [I]mplementation' },
      { '<leader>fi', '<cmd>FzfLua lsp_typedefs<cr>', desc = 'type def[i]nition' },
      { '<leader>fs', '<cmd>FzfLua lsp_document_symbols<cr>', desc = 'document [s]ymbols' },
      { '<leader>fw', '<cmd>FzfLua lsp_live_workspace_symbols<cr>', desc = '[w]orkspace symbols' },
    },
    after = function()
      require('fzf-lua').setup {
        files = {
          cmd = 'fd --type f --hidden --follow --exclude .git || find . -type f',
        },
        winopts = {
          border = 'none',
          preview = { border = 'noborder' },
        },
        grep = {
          actions = { ['ctrl-g'] = false },
        },
      }

      vim.keymap.set('n', '<leader>.', function()
        require('fzf-lua').blines {
          previewer = false,
          winopts = { height = 0.40, width = 0.60, row = 0.40 },
        }
      end, { desc = 'buffer fuzz search' })

      vim.keymap.set('n', '<leader>fn', function()
        require('fzf-lua').files {
          prompt = 'Neovim Config> ',
          cwd = vim.fn.stdpath 'config',
        }
      end, { desc = '[n]eovim files' })

      vim.keymap.set('n', '<leader>ft', function()
        require('fzf-lua').git_worktrees {
          actions = {
            ['default'] = function(selected)
              local new_wt = selected[1]:match '^(%S+)'
              local old_wt = vim.fn.getcwd()
              local current_file = vim.fn.expand '%:p'
              local rel_path = current_file:gsub('^' .. vim.pesc(old_wt) .. '/', '')
              vim.cmd('cd ' .. new_wt)
              local new_file = new_wt .. '/' .. rel_path
              if vim.fn.filereadable(new_file) == 1 then
                vim.cmd('edit ' .. new_file)
              end
            end,
          },
        }
      end, { desc = 'work[t]rees' })
    end,
  },
}
