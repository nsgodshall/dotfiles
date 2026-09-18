-- You can add your own plugins here or in other files in this directory!
--  I promise not to create any merge conflicts in this directory :)
--
-- See the kickstart.nvim README for more information

local specs = {}
local plugins_dir = vim.fs.joinpath(vim.fn.stdpath 'config', 'lua', 'custom', 'plugins')

for file_name, entry_type in vim.fs.dir(plugins_dir, { follow = true }) do
  if (entry_type == 'file' or entry_type == 'link') and file_name:match '%.lua$' and file_name ~= 'init.lua' then
    local module = file_name:gsub('%.lua$', '')
    local ok, mod = pcall(require, 'custom.plugins.' .. module)

    if not ok then
      vim.notify(('Failed to load custom plugin module %s: %s'):format(module, mod), vim.log.levels.ERROR)
    elseif type(mod) == 'table' then
      if #mod > 0 then
        vim.list_extend(specs, mod)
      elseif next(mod) ~= nil then
        specs[#specs + 1] = mod
      end
    elseif mod ~= nil then
      vim.notify(('custom.plugins.%s must return a table or nil'):format(module), vim.log.levels.ERROR)
    end
  end
end

return specs
