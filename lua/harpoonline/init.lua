-- Module definition ==========================================================

---@class HarpoonlineData
---@field list_name string|nil -- the name of the current list
---@field list_length number -- the length of the current list
---@field buffer_idx number|nil -- the mark of the current buffer if harpooned

--The signature of a formatter function:
---@alias HarpoonlineFormatter fun(data: HarpoonlineData): string

---@class HarpoonLine
local Harpoonline = {}
local H = {} -- helpers

---@param config? HarpoonLineConfig
Harpoonline.setup = function(config)
  local has_harpoon, Harpoon = pcall(require, 'harpoon')
  if not has_harpoon then return end

  H.harpoon_plugin = Harpoon

  config = H.setup_config(config)
  H.apply_config(config)

  H.produce() -- initialize the line
  if config.on_update then
    local produce = H.produce
    H.produce = function() -- composition with on_update
      produce()
      config.on_update() -- notify clients
    end
  end

  H.create_autocommands()
  H.create_extensions(require('harpoon.extensions'))
end

---@class HarpoonLineConfig
Harpoonline.config = {
  -- other nice icons: "󰀱", "", "󱡅"
  ---@type string
  icon = '󰀱', -- An empty string disables showing the icon

  -- Harpoon:list(), when name is nil, retrieves the default list:
  -- default_list_name: Configures the display name for the default list.
  ---@type string
  default_list_name = '',

  ---@type "extended" | "short"
  formatter = 'extended', -- use a builtin formatter

  formatter_opts = {
    extended = {
      -- An indicator corresponds to a position in the harpoon list
      -- Suggestion: Add an indicator for each configured "select" keybinding
      indicators = { ' 1 ', ' 2 ', ' 3 ', ' 4 ' },
      active_indicators = { '[1]', '[2]', '[3]', '[4]' },

      -- 1 More indicators than items in the harpoon list:
      empty_slot = '', -- ' · ', -- middledot. Disable using empty string

      -- 2 Less indicators than items in the harpoon list
      more_marks_indicator = ' … ', -- horizontal elipsis. Disable using empty string
      more_marks_active_indicator = '[…]', -- Disable using empty string
    },
    short = {
      inner_separator = '|',
    },
  },

  ---@type HarpoonlineFormatter
  custom_formatter = nil, -- use this formatter when configured

  ---@type fun()|nil
  on_update = nil, -- optional action to perform after the line has been rebuild.
}

-- Module functionality =======================================================

---@class HarpoonlineFormatterConfig
Harpoonline.formatters = {
  extended = function() return H.builtin_extended end,
  short = function() return H.builtin_short end,
}

-- Return true is the current buffer is harpooned, false otherwise
-- Useful for extra highlighting
---@return boolean
Harpoonline.is_buffer_harpooned = function() return H.current_buffer_idx ~= nil end

-- The function to be used by consumers
---@return string
Harpoonline.format = function() return H.cached_line end

-- Helper data ================================================================

H.harpoon_plugin = nil

---@type HarpoonlineFormatter
H.formatter = nil

---@type HarpoonLineConfig
H.default_config = vim.deepcopy(Harpoonline.config)

---@type string
H.cached_line = ''
---@type string | nil
H.list_name = nil
---@type number | nil
H.current_buffer_idx = nil

-- Helper functionality =======================================================

---@param config? HarpoonLineConfig
---@return HarpoonLineConfig
H.setup_config = function(config)
  vim.validate({ config = { config, 'table', true } })
  config = vim.tbl_deep_extend('force', vim.deepcopy(H.default_config), config or {})

  vim.validate({ icon = { config.icon, 'string' } })
  vim.validate({ default_list_name = { config.default_list_name, 'string' } })
  vim.validate({ formatter = { config.formatter, 'string' } })
  vim.validate({ formatter_opts = { config.formatter_opts, 'table' } })
  vim.validate({ custom_formatter = { config.custom_formatter, 'function', true } })
  vim.validate({ on_update = { config.on_update, 'function', true } })
  return config
end

-- Sets the final config to use.
-- If config.custom_formatter is configured, this will be the final formatter.
-- Otherwise, use builtin config.formatter if its valid.
-- Otherwise, fallback to the "extended" builtin formatter
---@param config HarpoonLineConfig
H.apply_config = function(config)
  Harpoonline.config = config

  if config.custom_formatter then
    H.formatter = config.custom_formatter
  else
    local builtin = Harpoonline.formatters[config.formatter]
    H.formatter = builtin and builtin() or H.builtin_extended
  end
end

---@return HarpoonLineConfig
H.get_config = function() return Harpoonline.config end

-- Update the data on each BufEnter event
-- Update the name of the list on custom event HarpoonSwitchedList
H.create_autocommands = function()
  local augroup = vim.api.nvim_create_augroup('Harpoonline', {})

  vim.api.nvim_create_autocmd('User', {
    group = augroup,
    pattern = 'HarpoonSwitchedList',
    callback = function(event)
      H.list_name = event.data
      H.produce()
    end,
  })

  vim.api.nvim_create_autocmd({ 'BufEnter' }, {
    group = augroup,
    pattern = '*',
    callback = H.produce,
  })
end

-- Update the data when the user adds to or removes from a list.
-- Needed because those actions can be done without leaving the buffer.
-- All other update scenarios are covered by listening to the BufEnter event.
H.create_extensions = function(Extensions)
  H.harpoon_plugin:extend({ [Extensions.event_names.ADD] = H.produce })
  H.harpoon_plugin:extend({ [Extensions.event_names.REMOVE] = H.produce })
end

-- If the current buffer is harpooned, return the index of the harpoon mark
-- Otherwise, return nil
---@param list HarpoonList
---@return number|nil
H.find_current_buffer_idx = function(list)
  if vim.bo.buftype ~= '' then return end -- not a normal buffer

  -- if list:length() == 0 --  NOTE: Harpoon issue #555
  if #list.items == 0 then return end -- no items in the list

  local current_file = vim.fn.expand('%:p:.')
  for idx, item in ipairs(list.items) do
    if item.value == current_file then return idx end
  end
end

-- To be invoked on any harpoon-related event
-- Performs action on_update if present
H.produce = function()
  ---@type HarpoonList
  local list = H.harpoon_plugin:list(H.list_name)
  H.current_buffer_idx = H.find_current_buffer_idx(list)

  H.cached_line = H.formatter({
    list_name = H.list_name,
    -- list_length = list:length(), -- NOTE: Harpoon issue #555
    list_length = #list.items,
    buffer_idx = H.current_buffer_idx,
  })
end

-- Return either the icon or an empty string
---@return string
H.make_icon = function()
  local icon = H.get_config().icon
  return icon ~= '' and icon or ''
end

---@param data HarpoonlineData
---@return string
H.builtin_short = function(data)
  local opts = H.get_config().formatter_opts.short
  local icon = H.make_icon()
  local list_name = data.list_name and data.list_name or H.get_config().default_list_name
  return string.format(
    '%s%s%s[%s%d]',
    icon,
    icon == '' and '' or ' ',
    list_name, -- no space after list name...
    data.buffer_idx and string.format('%s%s', data.buffer_idx, opts.inner_separator) or '',
    data.list_length
  )
end

---@param data HarpoonlineData
---@return string
H.builtin_extended = function(data)
  local opts = H.get_config().formatter_opts.extended
  local show_empty_slots = opts.empty_slot and opts.empty_slot ~= ''

  -- build prefix
  local show_prefix = true -- show_empty_slots or data.number_of_tags > 0
  local icon = H.make_icon()
  local list_name = data.list_name and data.list_name or H.get_config().default_list_name
  local prefix = not show_prefix and ''
    or string.format(
      '%s%s%s', --
      icon,
      list_name == '' and '' or ' ',
      list_name
    )

  -- build slots
  local nr_of_slots = #opts.indicators
  local status = {}
  for i = 1, nr_of_slots do
    if i > data.list_length then -- more slots then ...
      if show_empty_slots then table.insert(status, opts.empty_slot) end
    elseif i == data.buffer_idx then
      table.insert(status, opts.active_indicators[i])
    else
      table.insert(status, opts.indicators[i])
    end
  end
  -- add more marks indicator
  if data.list_length > nr_of_slots then -- more marks then...
    local ind = opts.more_marks_indicator
    if data.buffer_idx and data.buffer_idx > nr_of_slots then ind = opts.more_marks_active_indicator end
    if ind and ind ~= '' then table.insert(status, ind) end
  end

  prefix = prefix == '' and prefix or prefix .. ' '
  return prefix .. table.concat(status)
end

return Harpoonline
