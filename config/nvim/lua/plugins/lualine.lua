require('lze').load {
  {
    'lualine.nvim',
    event = 'DeferredUIEnter',
    after = function()
      local base_opts = {
        options = { theme = 'earthtone' },
        sections = {
          lualine_a = { 'mode' },
          lualine_b = { 'branch', 'diff', 'diagnostics' },
          lualine_c = {
            { 'filename', path = 3 },
            {
              function()
                return require('nvim-navic').get_location()
              end,
              cond = function()
                return package.loaded['nvim-navic'] and require('nvim-navic').is_available()
              end,
            },
          },
          lualine_x = { 'encoding', 'fileformat', 'filetype' },
          lualine_y = { 'progress' },
          lualine_z = { 'location' },
        },
      }

      require('lualine').setup(base_opts)
    end,
  },
}
