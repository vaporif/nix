require('lze').load {
  {
    'conform.nvim',
    event = 'BufWritePre',
    cmd = 'ConformInfo',
    after = function()
      require('conform').setup {
        notify_on_error = false,
        format_on_save = function(bufnr)
          local disable_filetypes = { c = true, cpp = true }
          local lsp_format_opt
          if disable_filetypes[vim.bo[bufnr].filetype] then
            lsp_format_opt = 'never'
          else
            lsp_format_opt = 'fallback'
          end
          return { timeout_ms = 500, lsp_format = lsp_format_opt }
        end,
        formatters_by_ft = {
          lua = { 'stylua' },
          go = { 'golangci_lint' },
        },
        formatters = {
          golangci_lint = {
            command = 'golangci-lint',
            args = { 'run', '--fix', '$FILENAME' },
            stdin = false,
          },
        },
      }
    end,
  },
}
