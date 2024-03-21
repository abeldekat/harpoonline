-- Module definition ==========================================================

local has_harpoon, Harpoon = pcall(require, 'harpoon')
local _, Extensions = pcall(require, 'harpoon.extensions')

---@class HarpoonLine
local Harpoonline = {}
local H = {} -- helpers

---@param config? HarpoonLineConfig
---@return HarpoonLine
Harpoonline.setup = function(config)
  if has_harpoon then
    config = H.setup_config(config)
    H.apply_config(config)

    H.create_autocommands()
    H.create_extensions()
    H.update_data()
  end
  return Harpoonline
end

---@class HarpoonLineConfig
Harpoonline.config = {
  -- suitable icons: "󰀱", "", "󱡅"
  ---@type string|nil
  icon = '󰀱',

  -- Harpoon:list() retrieves the default list: The name of that list is nil.
  -- default_list_name: Configures the display name for the default list.
  ---@type string
  default_list_name = '',

  ---@type string
  formatter = 'extended', -- short -- use a builtin formatter

  ---@type fun():string|nil
  custom_formatter = nil, -- use this formatter when configured
  ---@type fun()|nil
  on_update = nil, -- optional action to perform after update
}

---@class HarpoonlineFormatterConfig
Harpoonline.formatters = {
  extended = function() return { formatter = H.builtin_extended, opts = H.builtin_options_extended } end,
  short = function() return { formatter = H.builtin_short, opts = H.builtin_options_short } end,
}

-- Module functionality =======================================================

-- Given a formatter function, return a wrapper function that can be invoked
-- by consumers.
---@param formatter fun(data: HarpoonLineData, opts?: table):string
---@param opts? table
---@return function
Harpoonline.gen_formatter = function(formatter, opts)
  return opts and function() return formatter(H.data, opts) end or function() return formatter(H.data) end
end

-- Calls gen_formatter using a builtin formatter identified by name
-- Merges the options with the default options of that formatter
--
-- If name is not valied, "extended" will be used
---@param name string
---@param opts table
---@return function
Harpoonline.gen_override = function(name, opts)
  local config = H.get_builtin_config(name, opts)
  return Harpoonline.gen_formatter(config.formatter, config.opts)
end

-- Return true is the current buffer is harpooned, false otherwise
-- Useful for extra highlighting
---@return boolean
Harpoonline.is_buffer_harpooned = function() return H.data.buffer_idx and true or false end

-- The function to be used by consumers
---@return string
Harpoonline.format = function()
  if not H.cached_result then H.cached_result = H.formatter and H.formatter() or '' end
  return H.cached_result
end

-- Helper data ================================================================

---@type HarpoonLineConfig
H.default_config = vim.deepcopy(Harpoonline.config)

---@class HarpoonLineData
H.data = {
  --- @type string|nil
  list_name = nil, -- the name of the current list
  --- @type number
  list_length = 0, -- the length of the current list
  --- @type number|nil
  buffer_idx = nil, -- the mark of the current buffer if harpooned
}
-- @type string|nil
H.cached_result = nil

---@type fun():string|nil
H.formatter = nil

---@class HarpoonlineBuiltinOptionsShort
H.builtin_options_short = {
  inner_separator = '|',
}

---@class HarpoonlineBuiltinOptionsExtended
H.builtin_options_extended = {
  indicators = { '1', '2', '3', '4' },
  active_indicators = { '[1]', '[2]', '[3]', '[4]' },
  empty_slot = '·', -- interpunct, or middledot,
  more_marks_indicator = '…', -- horizontal elipsis
}

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
-- If config.custom_formatter is configured, this will be the final formatter.
-- Otherwise, use builtin config.formatter if its valid.
-- Otherwise, fallback to the "extended" builint formatter
---@param config HarpoonLineConfig
H.apply_config = function(config)
  if config.custom_formatter then
    H.formatter = config.custom_formatter
  else
    local formatter_config = H.get_builtin_config(config.formatter)
    H.formatter = Harpoonline.gen_formatter(formatter_config.formatter, formatter_config.opts)
  end
  Harpoonline.config = config
end

---@return HarpoonLineConfig
H.get_config = function() return Harpoonline.config end

-- Retuns the function and the options of the builtin config
-- identified by name.
-- The options are merged with the default options of the formatter.
---@param name string
---@param opts? table
---@return table
H.get_builtin_config = function(name, opts)
  local is_valid = vim.tbl_contains(vim.tbl_keys(Harpoonline.formatters), name)
  local key = is_valid and name or 'extended'
  local result = Harpoonline.formatters[key]()

  if opts then result.opts = vim.tbl_deep_extend('force', result.opts, opts) end
  return result
end

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
    callback = H.update,
  })
end

---@return HarpoonList
H.get_list = function() return Harpoon:list(H.data.list_name) end

-- If the current buffer is harpooned, return the index of the harpoon mark
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
-- All other update scenarios are covered by listening to the BufEnter event.
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

H.update_data = function()
  H.data.list_length = H.get_list():length()
  H.data.buffer_idx = H.buffer_idx()
end

-- To be invoked on any harpoon-related event
-- Performs action on_update if present
H.update = function()
  H.update_data()
  H.cached_result = nil -- the format function should recompute

  local on_update = H.get_config().on_update
  if on_update then on_update() end
end

---@param data HarpoonLineData
---@param opts HarpoonlineBuiltinOptionsShort
---@return string
H.builtin_short = function(data, opts)
  local icon = H.get_config().icon
  return string.format(
    '%s%s[%s%d]',
    icon and string.format('%s ', icon) or '',
    data.list_name and data.list_name or H.get_config().default_list_name,
    data.buffer_idx and string.format('%s%s', data.buffer_idx, opts.inner_separator) or '',
    data.list_length
  )
end

---@param data HarpoonLineData
---@param opts HarpoonlineBuiltinOptionsExtended
---@return string
H.builtin_extended = function(data, opts)
  --          ╭─────────────────────────────────────────────────────────╮
  --          │             credits letieu/harpoon-lualine              │
  --          ╰─────────────────────────────────────────────────────────╯
  local icon = H.get_config().icon
  local prefix = string.format(
    '%s%s',
    icon and string.format('%s ', icon) or '',
    data.list_name and data.list_name or H.get_config().default_list_name
  )

  local nr_of_indicators = #opts.indicators
  local indicator
  local status = {}
  for i = 1, nr_of_indicators do
    if i > data.list_length then
      indicator = opts.empty_slot
    elseif data.buffer_idx and data.buffer_idx == i then
      indicator = opts.active_indicators[i]
    else
      indicator = opts.indicators[i]
    end
    table.insert(status, indicator)
  end
  if (data.list_length > nr_of_indicators) and opts.more_marks_indicator then
    table.insert(status, opts.more_marks_indicator)
  end
  return prefix .. ' ' .. table.concat(status, ' ')
end

return Harpoonline
