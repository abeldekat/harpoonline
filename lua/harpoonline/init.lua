-- Module definition ==========================================================

-- suitable icons: "󰀱", "", "󱡅"
local Harpoon = require('harpoon')
local Extensions = require('harpoon.extensions')

---@class HarpoonLine
local Harpoonline = {}
local H = {}

---@param config? HarpoonLineConfig
---@return HarpoonLine
Harpoonline.setup = function(config)
  config = H.setup_config(config)
  H.apply_config(config)

  H.create_autocommands()
  H.create_extensions()
  return Harpoonline
end

---@class HarpoonLineConfig
Harpoonline.config = {
  icon = '󰀱', --   󱡅
  default_list_name = '',
  formatter = 'extended',

  ---@type fun():string|nil
  custom_formatter = nil, -- use this formatter when supplied
  on_update = nil, -- example: apply ministatusline.set_active
}

---@type table<string,function>
Harpoonline.formatters = {
  ---@param data HarpoonLineData
  ---@param _ any
  ---@return string
  simple = function(data, _)
    return string.format(
      '%s %s[%s%d]',
      H.get_config().icon,
      data.list_name and data.list_name or H.get_config().default_list_name,
      data.buffer_idx > 0 and string.format('%s|', data.buffer_idx) or '',
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
    local prefix =
      string.format('%s %s', H.get_config().icon, data.list_name and data.list_name or H.get_config().default_list_name)

    local length = #opts.indicators
    local status = {}
    for i = 1, length do
      local indicator
      if i > data.list_length then
        indicator = opts.empty_slot
      elseif data.buffer_idx == i then
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
  simple = {},
  extended = {
    indicators = { '1', '2', '3', '4' },
    active_indicators = { '[1]', '[2]', '[3]', '[4]' },
    empty_slot = '-',
  },
}

-- Module functionality =======================================================

---@param formatter fun(data: HarpoonLineData, opts?: table):string
---@param opts table
---@return function
Harpoonline.gen_formatter = function(formatter, opts)
  return function() return formatter(H.data, opts) end
end

---@return string
Harpoonline.format = function() return H.formatter and H.formatter() or '' end

---@return boolean
Harpoonline.is_buffer_harpooned = function() return H.data.buffer_idx > 0 end

-- Helper data ================================================================

---@type HarpoonLineConfig
H.default_config = vim.deepcopy(Harpoonline.config)

---@class HarpoonLineData
H.data = {
  list_name = nil, -- the default list
  list_length = 0,
  buffer_idx = -1,
}

---@type fun():string|nil
H.formatter = nil

-- Helper functionality =======================================================

---@param config? HarpoonLineConfig
---@return HarpoonLineConfig
H.setup_config = function(config)
  vim.validate({ config = { config, 'table', true } })
  config = vim.tbl_deep_extend('force', vim.deepcopy(H.default_config), config or {})

  vim.validate({ icon = { config.icon, 'string' } })
  vim.validate({ default_list_name = { config.default_list_name, 'string' } })
  vim.validate({ formatter = { config.formatter, 'string' } })
  vim.validate({ custom_formatter = { config.custom_formatter, 'function', true } })
  vim.validate({ on_update = { config.on_update, 'function', true } })
  return config
end

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

H.get_list = function() return Harpoon:list(H.data.list_name) end

---@return number
H.buffer_idx = function()
  -- For more information see ":h buftype"
  local not_found = -1

  if vim.bo.buftype ~= '' then return not_found end -- not a normal buffer

  local current_file = vim.fn.expand('%:p:.')
  local marks = H.get_list().items
  for idx, item in ipairs(marks) do
    if item.value == current_file then return idx end
  end
  return not_found
end

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

H.update = function()
  H.data.list_length = H.get_list():length()
  H.data.buffer_idx = H.buffer_idx()

  local on_update = H.get_config().on_update
  if on_update then on_update() end
end

return Harpoonline
