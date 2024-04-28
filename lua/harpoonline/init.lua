-- Moddefinition ==========================================================

---@class HarpoonlineData
---@field list_name string|nil -- the name of the current list
---@field items HarpoonItem[] -- the items of the current list
---@field active_idx number|nil -- the harpoon index of the current buffer

--The signature of a formatter function:
---@alias HarpoonlineFormatter fun(data: HarpoonlineData, opts: HarpoonLineConfig): string

---@class HarpoonLine
local Harpoonline = {}
local H = {} -- helpers

---@param config? HarpoonLineConfig
Harpoonline.setup = function(config)
  local has_harpoon, Harpoon = pcall(require, 'harpoon')
  if not has_harpoon then return end

  H.harpoon_plugin = Harpoon
  H.apply_config(H.setup_config(config))

  H.produce() -- initialize the line
  if H.get_config().on_update then
    local produce = H.produce
    H.produce = function() -- composition: add on_update
      produce()
      H.get_config().on_update() -- notify clients
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

  ---@type "default" | "short"
  formatter = 'default', -- use a builtin formatter

  formatter_opts = {
    default = {
      inactive = ' %s ', -- including spaces
      active = '[%s]',
      -- Number of slots to display:
      max_slots = 4, -- Suggestion: as many as there are "select" keybindings
      -- The number of items in the harpoon list exceeds max_slots:
      more = '…', -- horizontal elipsis. Disable using empty string
    },
    short = {
      inner_separator = '|',
    },
  },

  ---@type HarpoonlineFormatter
  custom_formatter = nil, -- use this formatter when configured

  ---@type fun()|nil
  on_update = nil, -- Recommended: trigger the client when the line has been rebuild.
}

-- Module functionality =======================================================

---@class HarpoonlineFormatterConfig
Harpoonline.formatters = {
  default = function() return H.builtin_default end,
  short = function() return H.builtin_short end,
}

-- Return true is the current buffer is harpooned, false otherwise
-- Useful for extra highlighting
---@return boolean
Harpoonline.is_buffer_harpooned = function() return H.active_idx ~= nil end

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
H.active_idx = nil

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
    H.formatter = builtin and builtin() or H.builtin_default
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
H.find_active_idx = function(list)
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
  H.active_idx = H.find_active_idx(list)

  H.cached_line = H.formatter({
    list_name = H.list_name,
    -- list_length = list:length(), -- NOTE: Harpoon issue #555
    items = list.items,
    active_idx = H.active_idx,
  }, H.get_config())
end

-- Returns the name of the list, or the configured default_list_name
H.make_list_name = function(name) return name and name or H.get_config().default_list_name end

-- Return either the icon or an empty string
---@return string
H.make_icon = function()
  local icon = H.get_config().icon
  return icon ~= '' and icon or ''
end

---@param data HarpoonlineData
---@param opts HarpoonLineConfig
---@return string
H.builtin_short = function(data, opts)
  local icon = H.make_icon()
  local list_name = H.make_list_name(data.list_name)

  local o = opts.formatter_opts.short
  return string.format(
    '%s%s%s[%s%d]',
    icon,
    icon == '' and '' or ' ',
    list_name, -- no space after list name...
    data.active_idx and string.format('%s%s', data.active_idx, o.inner_separator) or '',
    #data.items
  )
end

---@param data HarpoonlineData
---@param opts HarpoonLineConfig
---@return string
H.builtin_default = function(data, opts)
  local list_name = H.make_list_name(data.list_name)
  local header = string.format('%s%s%s', H.make_icon(), list_name == '' and '' or ' ', list_name)

  local o = opts.formatter_opts.default
  local idx = data.active_idx
  local slot = 0
  local slots = vim.tbl_map(function()
    slot = slot + 1
    return string.format(idx and idx == slot and o.active or o.inactive, slot)
  end, vim.list_slice(data.items, 1, math.min(o.max_slots, #data.items)))

  if #data.items > o.max_slots then
    if o.more and o.more ~= '' then
      local fmt = idx and idx > o.max_slots and o.active or o.inactive
      table.insert(slots, string.format(fmt, o.more))
    end
  end
  return header .. (header == '' and '' or ' ') .. table.concat(slots)
end

return Harpoonline
