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
          },
          lualine_x = { 'encoding', 'fileformat', 'filetype' },
          lualine_y = { 'progress' },
          lualine_z = { 'location' },
        },
      }

      local trouble = require 'trouble'
      local symbols = trouble.statusline {
        mode = 'lsp_document_symbols',
        groups = {},
        title = false,
        filter = { range = true },
        format = '{kind_icon}{symbol.name:Normal}',
        hl_group = 'lualine_c_normal',
      }

      table.insert(base_opts.sections.lualine_c, {
        symbols.get,
        cond = symbols.has,
      })

      require('lualine').setup(base_opts)
    end,
  },
}
