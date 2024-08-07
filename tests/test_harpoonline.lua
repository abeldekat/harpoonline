local MiniTest = require('mini.test')
local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

---@class MiniTestChildNeovim
---@field stop function
---@field restart function
---@field lua function
---@field lua_get function
---@field cmd function

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

local icon = '󰛢'
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
T['setup()']['can be invoked'] = function()
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
T['format()']['default'] = new_set()
T['format()']['default']['one harpoon'] = function()
  child.lua([[M.setup()]])
  add_files_to_list({ '1' })
  eq(child.lua_get([[ M.format() ]]), icon .. ' [1]')
end
T['format()']['default']['four harpoons'] = function()
  child.lua([[M.setup()]])
  add_files_to_list({ '1', '2', '3', '4' })
  eq(child.lua_get([[ M.format() ]]), icon .. '  1  2  3 [4]')
end
T['format()']['default']['six harpoons'] = function()
  child.lua([[M.setup()]])
  add_files_to_list({ '1', '2', '3', '4', '5', '6' })
  eq(child.lua_get([[ M.format() ]]), icon .. '  1  2  3  4 [' .. more .. ']')
end
T['format()']['default']['more marks'] = function()
  child.lua([[
    M.setup({
      formatter_opts = { default = {
        more = ""
      }}
    })
  ]])
  add_files_to_list({ '1', '2', '3', '4', '5', '6' })
  eq(child.lua_get([[ M.format() ]]), icon .. '  1  2  3  4 ')
end
T['format()']['default']['buffer not harpooned'] = function()
  child.lua([[M.setup()]])
  add_files_to_list({ '1', '2', '3', '4', '5' })
  edit('9')
  eq(child.lua_get([[ M.format() ]]), icon .. '  1  2  3  4  ' .. more .. ' ')
end
T['format()']['default']['remove item'] = function()
  child.lua([[M.setup()]])
  add_files_to_list({ '1', '2', '3' })
  child.lua([[ require("harpoon"):list():remove_at(3) ]])
  eq(child.lua_get([[ M.format() ]]), icon .. '  1  2 ')
end
T['format()']['default']['remove all items'] = function()
  child.lua([[M.setup()]])
  add_files_to_list({ '1', '2' })
  child.lua([[ require("harpoon"):list():remove_at(2) ]])
  child.lua([[ require("harpoon"):list():remove_at(1) ]])
  eq(child.lua_get([[ M.format() ]]), icon .. ' ') -- should be empty

  -- eq(child.lua_get([[ M.format() ]]), icon .. '  1 ') -- should be empty
  -- MiniTest.add_note('Incorrect, not empty!  See harpoon issue #555')
end
T['format()']['default']['switch list'] = function()
  child.lua([[M.setup()]])
  add_files_to_list({ '1', '2' }, 'dev')
  child.lua([[
    vim.api.nvim_exec_autocmds("User", {
      pattern = "HarpoonSwitchedList", modeline = false, data = "dev"
    })
  ]])
  eq(child.lua_get([[ M.format() ]]), icon .. ' dev  1 [2]')
end
T['format()']['default']['default_list_name'] = function()
  child.lua([[M.setup({default_list_name="mainlist"})]])
  add_files_to_list({ '1', '2' })
  eq(child.lua_get([[ M.format() ]]), icon .. ' mainlist  1 [2]')
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
T['format()']['short']['switch list'] = function()
  child.lua([[M.setup({ formatter = "short" })]])
  add_files_to_list({ '1', '2' }, 'dev')
  child.lua([[
    vim.api.nvim_exec_autocmds("User", {
      pattern = "HarpoonSwitchedList", modeline = false, data = "dev"
    })
  ]])
  eq(child.lua_get([[ M.format() ]]), icon .. ' dev[2|2]')
end
T['format()']['short']['default_list_name'] = function()
  child.lua([[M.setup({ formatter = "short", default_list_name = "mainlist" })]])
  add_files_to_list({ '1', '2' })
  eq(child.lua_get([[ M.format() ]]), icon .. ' mainlist[2|2]')
end

--          ╭─────────────────────────────────────────────────────────╮
--          │                    Custom formatter                     │
--          ╰─────────────────────────────────────────────────────────╯
T['format()']['custom'] = function()
  child.lua([[
    M.setup({
      custom_formatter = function(data, _)
        return string.format("%s%s%s%s",
          "Harpoonline: ",
          data.active_idx and "Buffer is harpooned " or "Buffer is not harpooned ",
          "in list ",
          data.list_name and data.list_name or "default"
        )
      end
    })
  ]])
  add_files_to_list({ '1', '2' })
  eq(child.lua_get([[M.format()]]), 'Harpoonline: Buffer is harpooned in list default')
end

return T
