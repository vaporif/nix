local hint_ns = vim.api.nvim_create_namespace 'yanky_hint'
local hint_augroup = vim.api.nvim_create_augroup('yanky_hint', { clear = true })

local function put_with_hint(plug)
  return function()
    local keys = vim.api.nvim_replace_termcodes(plug, true, true, true)
    vim.api.nvim_feedkeys(keys, 'm', false)
    vim.schedule(function()
      local buf = vim.api.nvim_get_current_buf()
      local row = vim.api.nvim_win_get_cursor(0)[1] - 1
      vim.api.nvim_buf_clear_namespace(buf, hint_ns, 0, -1)
      vim.api.nvim_buf_set_extmark(buf, hint_ns, row, 0, {
        virt_text = { { '  <C-p>prev  <C-n>next', 'Comment' } },
        virt_text_pos = 'eol',
      })
      vim.api.nvim_clear_autocmds { group = hint_augroup }
      vim.api.nvim_create_autocmd({ 'CursorMoved', 'InsertEnter' }, {
        group = hint_augroup,
        once = true,
        callback = function()
          vim.api.nvim_buf_clear_namespace(buf, hint_ns, 0, -1)
        end,
      })
    end)
  end
end

require('lze').load {
  {
    'yanky.nvim',
    dep_of = 'substitute.nvim',
    event = 'DeferredUIEnter',
    keys = {
      { 'p', put_with_hint '<Plug>(YankyPutAfter)', mode = { 'n', 'x' }, desc = 'Put after' },
      { 'P', put_with_hint '<Plug>(YankyPutBefore)', mode = { 'n', 'x' }, desc = 'Put before' },
      { 'gp', put_with_hint '<Plug>(YankyGPutAfter)', mode = { 'n', 'x' }, desc = 'GPut after' },
      { 'gP', put_with_hint '<Plug>(YankyGPutBefore)', mode = { 'n', 'x' }, desc = 'GPut before' },
      { '<c-p>', '<Plug>(YankyPreviousEntry)', desc = 'Yanky previous' },
      { '<c-n>', '<Plug>(YankyNextEntry)', desc = 'Yanky next' },
    },
    after = function()
      require('yanky').setup {
        preserve_cursor_position = { enabled = true },
      }
    end,
  },
  {
    'substitute.nvim',
    keys = {
      {
        's',
        function()
          require('substitute').operator()
        end,
        desc = 'Substitute',
      },
      {
        'ss',
        function()
          require('substitute').line()
        end,
        desc = 'Substitute line',
      },
      {
        'S',
        function()
          require('substitute').eol()
        end,
        desc = 'Substitute to EOL',
      },
      {
        's',
        function()
          require('substitute').visual()
        end,
        mode = 'x',
        desc = 'Substitute',
      },
    },
    after = function()
      require('substitute').setup {
        on_substitute = function(event)
          require('yanky.integration').substitute()(event)
        end,
        highlight_substituted_text = { enabled = true, timer = 300 },
      }
    end,
  },
}
