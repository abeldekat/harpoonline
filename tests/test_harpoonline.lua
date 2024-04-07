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

---@type MiniTestChildNeovim
local child = MiniTest.new_child_neovim() -- Create (but not start) child Neovim object

--          ╭─────────────────────────────────────────────────────────╮
--          │                         Helpers                         │
--          ╰─────────────────────────────────────────────────────────╯
local edit = function(name) child.cmd('edit tests/dir-harpoonline/real-files/' .. name) end
local add = function(names)
  for _, name in ipairs(names) do
    edit(name)
    child.lua([[ require("harpoon"):list():add() ]])
  end
end
-- local add_dev = function(names)
--   for _, name in ipairs(names) do
--     edit(name)
--     child.lua([[ require("harpoon"):list("dev"):add() ]])
--   end
-- end

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
      Harpoon:setup()
      Harpoon:list():clear()
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
  child.lua([[
    M.setup({ icon = '' })
  ]])
  add({ '1', '2' })
  eq(child.lua_get([[ M.format() ]]), ' 1 [2]')
end

T['format()'] = new_set()
--          ╭─────────────────────────────────────────────────────────╮
--          │                    Default formatter                    │
--          ╰─────────────────────────────────────────────────────────╯
T['format()']['extended'] = new_set()
T['format()']['extended']['one harpoon'] = function()
  child.lua([[M.setup()]])
  add({ '1' })
  eq(child.lua_get([[ M.format() ]]), icon .. ' [1]')
end
T['format()']['extended']['four harpoons'] = function()
  child.lua([[M.setup()]])
  add({ '1', '2', '3', '4' })
  eq(child.lua_get([[ M.format() ]]), icon .. '  1  2  3 [4]')
end
T['format()']['extended']['six harpoons'] = function()
  child.lua([[M.setup()]])
  add({ '1', '2', '3', '4', '5', '6' })
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
  add({ '1', '2' })
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
  add({ '1', '2' })
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
  add({ '1', '2', '3', '4', '5', '6' })
  eq(child.lua_get([[ M.format() ]]), icon .. '  1  2  3  4 ')
end
T['format()']['extended']['buffer not harpooned'] = function()
  child.lua([[M.setup()]])
  add({ '1', '2', '3', '4', '5' })
  edit('9')
  eq(child.lua_get([[ M.format() ]]), icon .. '  1  2  3  4  ' .. more .. ' ')
end
T['format()']['extended']['remove item'] = function()
  child.lua([[M.setup()]])
  add({ '1', '2', '3' })
  child.lua([[ require("harpoon"):list():remove_at(3) ]])
  eq(child.lua_get([[ M.format() ]]), icon .. '  1  2 ')
end
T['format()']['extended']['switch list'] = function()
  MiniTest.skip('WIP switch list: Autocommand')
  -- child.lua([[
  -- vim.api.nvim_exec_autocmds("User", {
  --   pattern = "HarpoonSwitchedList", modeline = false, data = "dev"
  -- })
  -- ]])
  -- add({ '1', '2' })
  -- eq(child.lua_get([[ M.format() ]]), icon .. '  dev 1  2 ')
end

--          ╭─────────────────────────────────────────────────────────╮
--          │                     Short formatter                     │
--          ╰─────────────────────────────────────────────────────────╯
T['format()']['short'] = new_set()
T['format()']['short']['skip'] = function() MiniTest.skip('WIP test short formatter') end

--          ╭─────────────────────────────────────────────────────────╮
--          │                    Custom formatter                     │
--          ╰─────────────────────────────────────────────────────────╯
T['format()']['custom'] = new_set()
T['format()']['custom']['skip'] = function() MiniTest.skip('WIP test custom formatter') end

return T
