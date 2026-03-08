require('lze').load {
  {
    'mini.nvim',
    event = 'DeferredUIEnter',
    after = function()
      require('mini.ai').setup { n_lines = 500 }
      require('mini.trailspace').setup()
    end,
  },
}
