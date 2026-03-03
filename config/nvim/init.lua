-- nix-info setup (values injected by nix-wrapper-modules)
do
  local ok, info = pcall(require, vim.g.nix_info_plugin_name)
  if ok then
    _G.nixInfo = info
  else
    local plugin_name = vim.g.nix_info_plugin_name or 'nix-info'
    package.loaded[plugin_name] = setmetatable({}, {
      __call = function(_, default)
        return default
      end,
    })
    _G.nixInfo = require(plugin_name)
  end
end

require 'core'

-- Load all plugin configs (each file calls require("lze").load)
local plugin_dir = vim.fn.stdpath 'config' .. '/lua/plugins'
local files = vim.fn.glob(plugin_dir .. '/*.lua', false, true)
table.sort(files)
for _, file in ipairs(files) do
  local module = file:match '.*/lua/(.*)%.lua$'
  if module then
    require(module:gsub('/', '.'))
  end
end
