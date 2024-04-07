-- TODO: Don't use vim.fs.joinpath, it's a nvim-0.10 feature
vim.fs.joinpath = vim.fs.joinpath
  or function(...)
    local path = table.concat({ ... }, '/')
    path = string.gsub(path, '//', '/')
    return path
  end

---@param name string directory name relative to test path
---@return string dir_path
local function path(name, temp_path) return vim.fs.joinpath(temp_path, name) end

-- Set up only when calling headless Neovim (like with `make test`)
if #vim.api.nvim_list_uis() == 0 then
  local root_path = vim.fn.fnamemodify('.', ':p')
  local temp_path = path('.tests', root_path)
  local plenary_path = path('plenary.nvim', temp_path)
  local harpoon_path = path('harpoon', temp_path)
  local mini_path = path('mini.nvim', temp_path)
  vim.opt.runtimepath = { vim.env.VIMRUNTIME, root_path, plenary_path, harpoon_path, mini_path }

  -- Needed for harpoon and git ci
  vim.env.XDG_DATA_HOME = path('data', temp_path)

  -- Set up 'mini.test'
  require('mini.test').setup()
end
