vim.diagnostic.config {
  virtual_text = false,
  virtual_lines = false,
  underline = true,
  float = {
    source = true,
  },
  signs = vim.g.have_nerd_font and {
    text = {
      [vim.diagnostic.severity.ERROR] = '',
      [vim.diagnostic.severity.WARN] = '',
      [vim.diagnostic.severity.HINT] = '',
      [vim.diagnostic.severity.INFO] = '',
    },
  } or true,
}

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities.textDocument.foldingRange.dynamicRegistration = false
capabilities.textDocument.foldingRange.lineFoldingOnly = true

vim.lsp.config('*', {
  capabilities = capabilities,
})

vim.lsp.config.lua_ls = {
  settings = {
    Lua = {
      completion = {
        callSnippet = 'Replace',
      },
      workspace = {
        library = { vim.env.VIMRUNTIME .. '/lua' },
      },
    },
  },
}
vim.lsp.enable 'lua_ls'
vim.lsp.enable 'ts_ls'
vim.lsp.config.gopls = {
  settings = {
    gopls = {
      gofumpt = true,
    },
  },
}
vim.lsp.enable 'gopls'

local corelib_path = os.getenv 'CAIRO_CORELIB_PATH'
vim.lsp.config.cairo_ls = {
  -- cmd = { vim.fn.expand '$HOME/.local/bin/scarb', 'cairo-language-server', '/C', '--node-ipc' },
  cmd = { 'scarb-cairo-language-server', '/C', '--node-ipc' },
  cmd_env = {
    SCARB_CONFIG = vim.fn.expand '$HOME/.scarb/config',
    SCARB_CACHE = vim.fn.expand '$HOME/.scarb/cache',
    CARGO_HOME = vim.fn.expand '$HOME/.cargo',
    TMPDIR = vim.fn.expand '$HOME/.tmp',
    PATH = vim.fn.expand '$HOME/.local/bin' .. ':' .. vim.env.PATH,
  },
  on_init = function()
    vim.fn.mkdir(vim.fn.expand '$HOME/.tmp', 'p')
    vim.fn.mkdir(vim.fn.expand '$HOME/.scarb/config', 'p')
    vim.fn.mkdir(vim.fn.expand '$HOME/.scarb/cache', 'p')
    vim.fn.mkdir(vim.fn.expand '$HOME/.cargo', 'p')
  end,
  settings = {
    cairo1 = {
      corelibPath = corelib_path,
    },
  },
}
vim.lsp.enable 'cairo_ls'

vim.lsp.config.nixd = {
  settings = {
    nixd = {
      formatting = {
        command = { 'alejandra', '-q' },
      },
    },
  },
  on_init = function(client)
    local root = client.config.root_dir or vim.fn.getcwd()
    local nixpkgs_expr = string.format('import (builtins.getFlake "%s").inputs.nixpkgs { }', root)
    client.config.settings = vim.tbl_deep_extend('force', client.config.settings, {
      nixd = { nixpkgs = { expr = nixpkgs_expr } },
    })
    client:notify('workspace/didChangeConfiguration', { settings = client.config.settings })
  end,
}

vim.lsp.enable 'nixd'

vim.lsp.config.basedpyright = {
  settings = {
    pyright = {
      -- disable import sorting and use Ruff for this
      disableOrganizeImports = true,
      disableTaggedHints = false,
    },
    python = {
      analysis = {
        autoSearchPaths = true,
        diagnosticMode = 'workspace',
        typeCheckingMode = 'standard',
        useLibraryCodeForTypes = true,
        -- we can this setting below to redefine some diagnostics
        diagnosticSeverityOverrides = {
          deprecateTypingAliases = false,
        },
        -- inlay hint settings are provided by pylance?
        inlayHints = {
          callArgumentNames = 'partial',
          functionReturnTypes = true,
          pytestParameters = true,
          variableTypes = true,
        },
      },
    },
  },
  capabilities = {
    textDocument = {
      publishDiagnostics = {
        tagSupport = {
          valueSet = { 2 },
        },
      },
      hover = {
        contentFormat = { 'plaintext' },
        dynamicRegistration = true,
      },
    },
  },
}

vim.lsp.enable 'basedpyright'

vim.lsp.config.ruff = {
  settings = {
    organizeImports = false,
  },
}
vim.lsp.enable 'ruff'

vim.lsp.config.just_ls = {}
vim.lsp.enable 'just_ls'

vim.lsp.config.solidity_ls_nomicfoundation = {
  cmd = { 'nomicfoundation-solidity-language-server', '--stdio' },
  filetypes = { 'solidity' },
  root_markers = { 'hardhat.config.js', 'hardhat.config.ts', 'foundry.toml', 'remappings.txt', '.git' },
}
vim.lsp.enable 'solidity_ls_nomicfoundation'

vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('lsp-attach', { clear = true }),
  callback = function(event)
    local client = vim.lsp.get_client_by_id(event.data.client_id)
    if client and client:supports_method 'textDocument/documentSymbol' then
      require('nvim-navic').attach(client, event.buf)
    end

    local map = function(keys, func, desc)
      vim.keymap.set('n', keys, func, { buffer = event.buf, desc = desc })
    end

    map('gD', vim.lsp.buf.declaration, 'goto [D]eclaration')
    vim.keymap.set('n', '<leader>r', function()
      return ':IncRename ' .. vim.fn.expand '<cword>'
    end, { buffer = event.buf, desc = '[r]ename', expr = true })
    map('<leader>ca', vim.lsp.buf.code_action, '[a]ction')
    map('<leader>cR', '<cmd>LspRestart<CR>', '[R]estart LSP')

    vim.keymap.set('n', '<leader>ci', function()
      vim.lsp.buf.code_action { context = { only = { 'source.organizeImports' }, diagnostics = {} }, apply = true }
    end, { buffer = 0, desc = 'organize [i]mports' })

    vim.api.nvim_create_autocmd('CursorHold', {
      buffer = event.buf,
      group = vim.api.nvim_create_augroup('lsp-diagnostic-float-' .. event.buf, { clear = true }),
      callback = function()
        if #vim.diagnostic.get(event.buf, { lnum = vim.api.nvim_win_get_cursor(0)[1] - 1 }) > 0 then
          vim.diagnostic.open_float(nil, {
            focus = false,
            scope = 'cursor',
            close_events = { 'CursorMoved', 'CursorMovedI', 'BufHidden', 'InsertEnter', 'WinLeave' },
          })
        end
      end,
    })
    -- Disable ruff hover feature in favor of Pyright
    if client and client.name == 'ruff' then
      client.server_capabilities.hoverProvider = false
    end
  end,
})
