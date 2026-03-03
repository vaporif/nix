require('lze').load {
  {
    'neo-tree.nvim',
    cmd = 'Neotree',
    after = function()
      require('neo-tree').setup {
        default_component_configs = {
          file_operations = { timeout = 0 },
        },
        filesystem = {
          commands = {
            delete = function(state)
              local inputs = require 'neo-tree.ui.inputs'
              local path = state.tree:get_node().path
              local msg = 'Are you sure you want to delete ' .. path .. '?'
              inputs.confirm(msg, function(confirmed)
                if confirmed then
                  vim.fn.jobstart({ 'rm', '-rf', path }, {
                    detach = true,
                    on_exit = function()
                      require('neo-tree.sources.manager').refresh 'filesystem'
                    end,
                  })
                end
              end)
            end,
          },
          filtered_items = { visible = true },
          follow_current_file = { enabled = true, leave_dirs_open = false },
          hijack_netrw_behavior = 'open_current',
          window = {
            popup = { border = 'none', title = '' },
            border = 'none',
            mappings = {
              ['e'] = 'none',
              ['h'] = function()
                vim.cmd 'Neotree float git_status'
              end,
              ['f'] = function()
                vim.cmd 'Neotree float filesystem'
              end,
              ['b'] = function()
                vim.cmd 'Neotree float buffers'
              end,
            },
          },
        },
      }
    end,
  },
}
