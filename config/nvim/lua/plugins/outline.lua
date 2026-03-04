require('lze').load {
  {
    'outline.nvim',
    cmd = { 'Outline', 'OutlineOpen' },
    keys = {
      { '<leader>co', '<cmd>Outline<CR>', desc = '[o]utline' },
    },
    after = function()
      require('outline').setup {}
    end,
  },
}
