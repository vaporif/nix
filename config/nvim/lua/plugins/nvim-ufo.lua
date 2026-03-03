require('lze').load {
  {
    'nvim-ufo',
    event = 'BufReadPost',
    after = function()
      require('ufo').setup {
        provider_selector = function()
          return { 'treesitter', 'indent' }
        end,
      }
    end,
  },
}
