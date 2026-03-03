require('lze').load {
  {
    'render-markdown.nvim',
    ft = 'markdown',
    after = function()
      require('render-markdown').setup {
        latex = { enabled = false },
      }
    end,
  },
}
