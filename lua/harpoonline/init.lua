-- Module definition ==========================================================

-- suitable icons: "󰀱", "", "󱡅"
local has_harpoon, Harpoon = pcall(require, 'harpoon')
local _, Extensions = pcall(require, 'harpoon.extensions')

---@class HarpoonLine
local Harpoonline = {}
local H = {}

---@param config? HarpoonLineConfig
---@return HarpoonLine
Harpoonline.setup = function(config)
  if has_harpoon then
    config = H.setup_config(config)
    H.apply_config(config)

    H.create_autocommands()
    H.create_extensions()
  end
  return Harpoonline
end

---@class HarpoonLineConfig
Harpoonline.config = {
  ---@type string|nil
  icon = '󰀱',

  -- As harpoon's default list is retrieved without a name,
  -- default_list_name configures the name to be displayed
  ---@type string
  default_list_name = '',

  ---@type string
  formatter = 'extended', -- use a builtin formatter

  ---@type fun():string|nil
  custom_formatter = nil, -- use this formatter when supplied
  ---@type fun()|nil
  on_update = nil, -- optional action to perform after update
}

-- A formatter is a function that transforms the data into a line
-- The first argument is the data, the second argument a table containing options
---@type table<string,function>
Harpoonline.formatters = {
  ---@param data HarpoonLineData
  ---@param _ any
  ---@return string
  short = function(data, _)
    local icon = H.get_config().icon
    return string.format(
      '%s%s[%s%d]',
      icon and string.format('%s ', icon) or '',
      data.list_name and data.list_name or H.get_config().default_list_name,
      data.buffer_idx and string.format('%s|', data.buffer_idx) or '',
      data.list_length
    )
  end,

  ---@param data HarpoonLineData
  ---@param opts table
  ---@return string
  extended = function(data, opts)
    --          ╭─────────────────────────────────────────────────────────╮
    --          │             credits letieu/harpoon-lualine              │
    --          ╰─────────────────────────────────────────────────────────╯
    local icon = H.get_config().icon
    local prefix = string.format(
      '%s%s',
      icon and string.format('%s ', icon) or '',
      data.list_name and data.list_name or H.get_config().default_list_name
    )

    local length = #opts.indicators
    local status = {}
    for i = 1, length do
      local indicator
      if i > data.list_length then
        indicator = opts.empty_slot
      elseif data.buffer_idx and data.buffer_idx == i then
        indicator = opts.active_indicators[i]
      else
        indicator = opts.indicators[i]
      end
      table.insert(status, indicator)
    end
    return prefix .. ' ' .. table.concat(status, ' ')
  end,
}
---@type table<string,table>
Harpoonline.formatter_opts = {
  short = {},
  extended = {
    indicators = { '1', '2', '3', '4' },
    active_indicators = { '[1]', '[2]', '[3]', '[4]' },
    empty_slot = '-',
  },
}

-- Module functionality =======================================================

-- Given a formatter function, return a wrapper function to be invoked
-- by statuslines.
-- The wrapper calls this function with two arguments:
--   - data: The internal cache from this module
--   - opts: The formatter specific options
---@param formatter fun(data: HarpoonLineData, opts?: table):string
---@param opts table
---@return function
Harpoonline.gen_formatter = function(formatter, opts)
  return function() return formatter(H.data, opts) end
end

-- Given a builtin formatter, return a wrapper function to be invoked
-- by statuslines. The options are merged with the default options
--
-- If the builtin is not a valid builtin formatter, "extended" will be used
---@param builtin string
---@param opts table
---@return function
Harpoonline.gen_override = function(builtin, opts)
  local is_valid = vim.tbl_contains(vim.tbl_keys(Harpoonline.formatters), builtin)
  local key = is_valid and builtin or 'extended'
  opts = vim.tbl_deep_extend('force', Harpoonline.formatter_opts[key], opts)
  return Harpoonline.gen_formatter(Harpoonline.formatters[key], opts)
end

-- Return true is the current buffer is harpooned, false otherwise
-- Useful for extra highlighting code
---@return boolean
Harpoonline.is_buffer_harpooned = function() return H.data.buffer_idx and true or false end

-- The function to be used by statuslines
---@return string
Harpoonline.format = function() return H.formatter and H.formatter() or '' end

-- Helper data ================================================================

---@type HarpoonLineConfig
H.default_config = vim.deepcopy(Harpoonline.config)

---@class HarpoonLineData
H.data = {
  --- @type string|nil
  list_name = nil, -- the name of the list in use
  --- @type number
  list_length = 0, -- the length of the list
  --- @type number|nil
  buffer_idx = nil, -- the harpoon index of the current buffer if harpooned
}

---@type fun():string|nil
H.formatter = nil

-- Helper functionality =======================================================

---@param config? HarpoonLineConfig
---@return HarpoonLineConfig
H.setup_config = function(config)
  vim.validate({ config = { config, 'table', true } })
  config = vim.tbl_deep_extend('force', vim.deepcopy(H.default_config), config or {})

  vim.validate({ icon = { config.icon, 'string', true } })
  vim.validate({ default_list_name = { config.default_list_name, 'string' } })
  vim.validate({ formatter = { config.formatter, 'string' } })
  vim.validate({ custom_formatter = { config.custom_formatter, 'function', true } })
  vim.validate({ on_update = { config.on_update, 'function', true } })
  return config
end

-- Sets the final config to use.
-- If config.custom_formatter is supplied, this will be the final formatter.
-- Otherwise, use builtin config.formatter if its valid.
-- Fallback to the "extended" formatter if config.formatter is not valid.
---@param config HarpoonLineConfig
H.apply_config = function(config)
  if config.custom_formatter then
    H.formatter = config.custom_formatter
  else
    local is_valid = vim.tbl_contains(vim.tbl_keys(Harpoonline.formatters), config.formatter)
    local key = is_valid and config.formatter or 'extended'
    H.formatter = Harpoonline.gen_formatter(Harpoonline.formatters[key], Harpoonline.formatter_opts[key])
  end
  Harpoonline.config = config
end

---@return HarpoonLineConfig
H.get_config = function() return Harpoonline.config end

-- Update the data on each BufEnter event
-- Update the name of the list on custom event HarpoonSwitchedList
H.create_autocommands = function()
  local augroup = vim.api.nvim_create_augroup('HarpoonLine', {})

  vim.api.nvim_create_autocmd('User', {
    group = augroup,
    pattern = 'HarpoonSwitchedList',
    callback = function(event)
      H.data.list_name = event.data
      H.update()
    end,
  })

  vim.api.nvim_create_autocmd({ 'BufEnter' }, {
    group = augroup,
    pattern = '*',
    callback = function() H.update() end,
  })
end

---@return HarpoonList
H.get_list = function() return Harpoon:list(H.data.list_name) end

-- If the current buffer is harpooned, return the index of the mark in harpoon's list
-- Otherwise, return nil
---@return number|nil
H.buffer_idx = function()
  if vim.bo.buftype ~= '' then return end -- not a normal buffer

  local current_file = vim.fn.expand('%:p:.')
  local marks = H.get_list().items
  for idx, item in ipairs(marks) do
    if item.value == current_file then return idx end
  end
end

-- Update the data when the user adds to or removes from a list.
-- Needed because those actions can be done without leaving the buffer.
-- All other update scenarios are covered by listening toe the BufEnter event.
H.create_extensions = function()
  Harpoon:extend({
    [Extensions.event_names.ADD] = function()
      vim.schedule(H.update) -- actual add occurs after
    end,
  })
  Harpoon:extend({
    [Extensions.event_names.REMOVE] = function()
      vim.schedule(H.update) -- actual remove occurs after
    end,
  })
end

-- Updates the data
-- Performs action on_update when configured
H.update = function()
  H.data.list_length = H.get_list():length()
  H.data.buffer_idx = H.buffer_idx()

  local on_update = H.get_config().on_update
  if on_update then on_update() end
end

return Harpoonline
