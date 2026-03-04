require('lze').load {
  {
    'blink.cmp',
    event = 'DeferredUIEnter',
    after = function()
      require('blink.cmp').setup {
        sources = {
          default = function()
            local sources = { 'lsp', 'path', 'snippets', 'buffer' }
            if vim.bo.filetype == 'lua' then
              table.insert(sources, 'lazydev')
            end
            return sources
          end,
          providers = {
            lsp = {
              name = 'lsp',
              module = 'blink.cmp.sources.lsp',
              fallbacks = { 'buffer' },
              score_offset = 90,
            },
            path = {
              name = 'Path',
              module = 'blink.cmp.sources.path',
              score_offset = 25,
              min_keyword_length = 3,
              fallbacks = { 'snippets', 'buffer' },
              opts = {
                trailing_slash = false,
                label_trailing_slash = true,
                get_cwd = function(context)
                  return vim.fn.expand(('#%d:p:h'):format(context.bufnr))
                end,
                show_hidden_files_by_default = true,
              },
            },
            buffer = {
              name = 'Buffer',
              max_items = 3,
              module = 'blink.cmp.sources.buffer',
              min_keyword_length = 2,
              score_offset = 50,
            },
            snippets = {
              name = 'snippets',
              max_items = 10,
              min_keyword_length = 2,
              module = 'blink.cmp.sources.snippets',
              score_offset = 70,
            },
            lazydev = { module = 'lazydev.integrations.blink', score_offset = 100 },
          },
        },
        appearance = { nerd_font_variant = 'mono' },
        cmdline = { enabled = true },
        signature = { enabled = true },
        completion = {
          trigger = { show_on_trigger_character = true },
          list = {
            selection = { preselect = true, auto_insert = true },
          },
          menu = {
            draw = {
              padding = { 0, 1 },
              components = {
                kind_icon = {
                  text = function(ctx)
                    return ' ' .. ctx.kind_icon .. ctx.icon_gap .. ' '
                  end,
                },
              },
            },
          },
          documentation = { auto_show = true },
        },
        fuzzy = { implementation = 'rust' },
        keymap = {
          preset = 'enter',
          ['<Tab>'] = { 'snippet_forward', 'fallback' },
          ['<S-Tab>'] = { 'snippet_backward', 'fallback' },
          ['<C-y>'] = { 'select_and_accept' },
          ['<Up>'] = { 'select_prev' },
          ['<Down>'] = { 'select_next' },
          ['<C-p>'] = { 'select_prev', 'fallback' },
          ['<C-n>'] = { 'select_next', 'fallback' },
          ['<S-j>'] = { 'scroll_documentation_up', 'fallback' },
          ['<S-k>'] = { 'scroll_documentation_down', 'fallback' },
          ['<C-space>'] = { 'show', 'show_documentation', 'hide_documentation' },
          ['<C-e>'] = { 'hide', 'fallback' },
        },
      }
    end,
  },
}
