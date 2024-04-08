local MiniTest = require('mini.test')
local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality
-- local expect = MiniTest.expect

---@class MiniTestChildNeovim
---@field stop function
---@field restart function
---@field lua function
---@field lua_get function
---@field cmd function
---@field api function

---@type MiniTestChildNeovim
local child = MiniTest.new_child_neovim() -- Create (but not start) child Neovim object

--          ╭─────────────────────────────────────────────────────────╮
--          │                         Helpers                         │
--          ╰─────────────────────────────────────────────────────────╯
local edit = function(name) child.cmd('edit tests/dir-harpoonline/real-files/' .. name) end
local add_current_buffer = function(list_name)
  local add = string.format(
    '%s%s%s', -- compose the require statement
    'require("harpoon"):list(',
    list_name and '"' .. list_name .. '"' or '',
    '):add()'
  )
  child.lua(add)
end
local add_files_to_list = function(names, list_name)
  for _, name in ipairs(names) do
    edit(name) -- will be the current buffer
    add_current_buffer(list_name)
  end
end

local icon = '󰀱'
local more = '…'

--          ╭─────────────────────────────────────────────────────────╮
--          │                      Main testset                       │
--          ╰─────────────────────────────────────────────────────────╯
local T = new_set({ -- Define main test set of this file
  hooks = {
    pre_case = function()
      child.restart({ '-u', 'scripts/minimal_init.lua' })
      child.lua([[
      local Harpoon = require("harpoon")
      Harpoon:setup({ dev = {} }) -- add a "dev" list
      Harpoon:list():clear() -- harpoon data is persisted
      M = require('harpoonline') -- Load plugin to test
      ]])
    end,
    post_once = child.stop,
  },
})

--          ╭─────────────────────────────────────────────────────────╮
--          │                          Setup                          │
--          ╰─────────────────────────────────────────────────────────╯
T['setup()'] = new_set()
T['setup()']['returns default when not invoked'] = function() eq(child.lua_get([[M.format()]]), '') end
T['setup()']['works'] = function()
  child.lua([[M.setup()]])
  eq(child.lua_get([[M.format()]]), icon .. ' ')
end

--          ╭─────────────────────────────────────────────────────────╮
--          │                          Icon                           │
--          ╰─────────────────────────────────────────────────────────╯
T['no_icon'] = function()
  child.lua([[ M.setup({ icon = '' }) ]])
  add_files_to_list({ '1', '2' })
  eq(child.lua_get([[ M.format() ]]), ' 1 [2]')
end

T['format()'] = new_set()
--          ╭─────────────────────────────────────────────────────────╮
--          │                    Default formatter                    │
--          ╰─────────────────────────────────────────────────────────╯
T['format()']['extended'] = new_set()
T['format()']['extended']['one harpoon'] = function()
  child.lua([[M.setup()]])
  add_files_to_list({ '1' })
  eq(child.lua_get([[ M.format() ]]), icon .. ' [1]')
end
T['format()']['extended']['four harpoons'] = function()
  child.lua([[M.setup()]])
  add_files_to_list({ '1', '2', '3', '4' })
  eq(child.lua_get([[ M.format() ]]), icon .. '  1  2  3 [4]')
end
T['format()']['extended']['six harpoons'] = function()
  child.lua([[M.setup()]])
  add_files_to_list({ '1', '2', '3', '4', '5', '6' })
  eq(child.lua_get([[ M.format() ]]), icon .. '  1  2  3  4 [' .. more .. ']')
end
T['format()']['extended']['custom indicators'] = function()
  child.lua([[
    M.setup({
      formatter_opts = { extended = {
        indicators = {"A", "B"}, active_indicators = {"-A-", "-B-"}
      }}
    })
  ]])
  add_files_to_list({ '1', '2' })
  eq(child.lua_get([[ M.format() ]]), icon .. ' A-B-')
end
T['format()']['extended']['empty slots'] = function()
  child.lua([[
    M.setup({
      formatter_opts = { extended = {
        empty_slot = ' · '
      }}
    })
  ]])
  add_files_to_list({ '1', '2' })
  eq(child.lua_get([[ M.format() ]]), icon .. '  1 [2] ·  · ')
end
T['format()']['extended']['more marks'] = function()
  child.lua([[
    M.setup({
      formatter_opts = { extended = {
        more_marks_indicator = '', more_marks_active_indicator = '',
      }}
    })
  ]])
  add_files_to_list({ '1', '2', '3', '4', '5', '6' })
  eq(child.lua_get([[ M.format() ]]), icon .. '  1  2  3  4 ')
end
T['format()']['extended']['buffer not harpooned'] = function()
  child.lua([[M.setup()]])
  add_files_to_list({ '1', '2', '3', '4', '5' })
  edit('9')
  eq(child.lua_get([[ M.format() ]]), icon .. '  1  2  3  4  ' .. more .. ' ')
end
T['format()']['extended']['remove item'] = function()
  child.lua([[M.setup()]])
  add_files_to_list({ '1', '2', '3' })
  child.lua([[ require("harpoon"):list():remove_at(3) ]])
  eq(child.lua_get([[ M.format() ]]), icon .. '  1  2 ')
end
T['format()']['extended']['switch list'] = function()
  child.lua([[M.setup()]])
  add_files_to_list({ '1', '2' }, 'dev')
  child.lua([[
    vim.api.nvim_exec_autocmds("User", {
      pattern = "HarpoonSwitchedList", modeline = false, data = "dev"
    })
  ]])
  eq(child.lua_get([[ M.format() ]]), icon .. ' dev  1 [2]')
end

--          ╭─────────────────────────────────────────────────────────╮
--          │                     Short formatter                     │
--          ╰─────────────────────────────────────────────────────────╯
T['format()']['short'] = new_set()
T['format()']['short']['default'] = function()
  child.lua([[ M.setup({ formatter = "short", }) ]])
  add_files_to_list({ '1', '2' })
  eq(child.lua_get([[M.format()]]), icon .. ' [2|2]')
end
T['format()']['short']['buffer not harpooned'] = function()
  child.lua([[ M.setup({ formatter = "short", }) ]])
  add_files_to_list({ '1', '2' })
  edit('3')
  eq(child.lua_get([[M.format()]]), icon .. ' [2]')
end
T['format()']['short']['no harpoons'] = function()
  child.lua([[ M.setup({ formatter = "short", }) ]])
  eq(child.lua_get([[M.format()]]), icon .. ' [0]')
end
T['format()']['short']['inner_separator'] = function()
  child.lua([[
    M.setup({
      formatter = "short",
      formatter_opts = { short = {
        inner_separator = '-'
      }}
    })
  ]])
  add_files_to_list({ '1', '2' })
  eq(child.lua_get([[M.format()]]), icon .. ' [2-2]')
end

--          ╭─────────────────────────────────────────────────────────╮
--          │                    Custom formatter                     │
--          ╰─────────────────────────────────────────────────────────╯
T['format()']['custom'] = function()
  child.lua([[
    M.setup({
      custom_formatter = M.gen_formatter(
        function(data)
          return string.format("%s%s%s%s",
            "Harpoonline: ",
            data.buffer_idx and "Buffer is harpooned " or "Buffer is not harpooned ",
            "in list ",
            data.list_name and data.list_name or "default"
          )
        end
      )
    })
  ]])
  add_files_to_list({ '1', '2' })
  eq(child.lua_get([[M.format()]]), 'Harpoonline: Buffer is harpooned in list default')
end

return T
