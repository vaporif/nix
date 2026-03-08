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
    client.notify('workspace/didChangeConfiguration', { settings = client.config.settings })
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
    local map = function(keys, func, desc)
      vim.keymap.set('n', keys, func, { buffer = event.buf, desc = desc })
    end

    map('gr', vim.lsp.buf.references, 'goto [r]eferences')
    map('gD', vim.lsp.buf.declaration, 'goto [D]eclaration')
    map('<leader>r', vim.lsp.buf.rename, '[r]ename')
    map('<leader>ca', vim.lsp.buf.code_action, '[a]ction')
    map('<leader>cR', '<cmd>LspRestart<CR>', '[R]estart LSP')

    vim.keymap.set('n', '<leader>ci', function()
      vim.lsp.buf.code_action { context = { only = { 'source.organizeImports' }, diagnostics = {} }, apply = true }
    end, { buffer = 0, desc = 'organize [i]mports' })

    local client = vim.lsp.get_client_by_id(event.data.client_id)
    if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight) then
      local highlight_augroup = vim.api.nvim_create_augroup('lsp-highlight-' .. event.buf, { clear = true })

      vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
        buffer = event.buf,
        group = highlight_augroup,
        callback = function(args)
          if #vim.lsp.get_clients { bufnr = event.buf } > 0 then
            vim.lsp.buf.document_highlight()
          end
          if args.event == 'CursorHold' then
            vim.diagnostic.open_float(nil, {
              focus = false,
              scope = 'cursor',
              close_events = { 'CursorMoved', 'CursorMovedI', 'BufHidden', 'InsertEnter', 'WinLeave' },
            })
          end
        end,
      })

      vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
        buffer = event.buf,
        group = highlight_augroup,
        callback = vim.lsp.buf.clear_references,
      })
    end
    -- Disable ruff hover feature in favor of Pyright
    if client and client.name == 'ruff' then
      client.server_capabilities.hoverProvider = false
    end
  end,
})

vim.api.nvim_create_autocmd('LspDetach', {
  group = vim.api.nvim_create_augroup('lsp-detach', { clear = true }),
  callback = function(event)
    if #vim.lsp.get_clients { bufnr = event.buf } == 0 then
      pcall(vim.api.nvim_del_augroup_by_name, 'lsp-highlight-' .. event.buf)
      vim.lsp.buf.clear_references()
    end
  end,
})
