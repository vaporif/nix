require('lze').load {
  {
    'flash.nvim',
    keys = {
      {
        'l',
        function()
          require('flash').jump()
        end,
        mode = { 'n', 'x', 'o' },
        desc = 'Flash',
      },
      {
        'k',
        function()
          require('flash').treesitter()
        end,
        mode = { 'n', 'x', 'o' },
        desc = 'Flash Treesitter',
      },
      {
        'r',
        function()
          require('flash').remote()
        end,
        mode = 'o',
        desc = 'Remote Flash',
      },
      {
        '<c-s>',
        function()
          require('flash').toggle()
        end,
        mode = 'c',
        desc = 'Toggle Flash Search',
      },
    },
  },
}
