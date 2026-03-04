require('lze').load {
  {
    'difftastic.nvim',
    cmd = { 'Difft', 'DifftPick' },
    after = function()
      local difft = require 'difftastic-nvim'
      difft.setup {
        download = false,
        vcs = 'git',
        snacks_picker = { enabled = true },
      }

      local help_lines = {
        'Difftastic Keymaps:',
        '  ]f   Next file',
        '  [f   Previous file',
        '  ]c   Next hunk',
        '  [c   Previous hunk',
        '  Tab  Toggle tree/diff',
        '  CR   Select file (tree)',
        '  gf   Go to file',
        '  q    Close',
        '  g?   This help',
      }
      local help_text = table.concat(help_lines, '\n')

      local orig_open = difft.open
      difft.open = function(...)
        orig_open(...)
        for _, buf in ipairs { difft.state.left_buf, difft.state.right_buf, difft.state.tree_buf } do
          if buf and vim.api.nvim_buf_is_valid(buf) then
            vim.keymap.set('n', 'g?', function()
              vim.notify(help_text, vim.log.levels.INFO)
            end, { buffer = buf, desc = 'Difftastic help' })
          end
        end
        if difft.state.tree_win and vim.api.nvim_win_is_valid(difft.state.tree_win) then
          vim.wo[difft.state.tree_win].winbar = '%#Comment# g? help%*'
        end
      end
    end,
  },
}
