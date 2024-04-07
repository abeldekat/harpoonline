local new_set = MiniTest.new_set
local expect, eq = MiniTest.expect, MiniTest.expect.equality

local child = MiniTest.new_child_neovim() -- Create (but not start) child Neovim object

local T = new_set({ -- Define main test set of this file
  hooks = {
    pre_case = function()
      child.restart({ '-u', 'scripts/minimal_init.lua' })
      -- Load tested plugin
      child.lua([[M = require('harpoonline')]])
      -- Setup
      child.lua([[M.setup()]])
    end,
    post_once = child.stop,
  },
})

--          ╭─────────────────────────────────────────────────────────╮
--          │                        No setup                         │
--          ╰─────────────────────────────────────────────────────────╯
T['no_setup()'] = new_set()
T['no_setup()']['empty_line'] = function() eq(child.lua_get([[M.format()]]), '') end

--          ╭─────────────────────────────────────────────────────────╮
--          │                          Setup                          │
--          ╰─────────────────────────────────────────────────────────╯
T['setup()'] = new_set()

--          ╭─────────────────────────────────────────────────────────╮
--          │                       Formatters                        │
--          ╰─────────────────────────────────────────────────────────╯
T['formatters()'] = new_set()

--          ╭─────────────────────────────────────────────────────────╮
--          │                    Default formatter                    │
--          ╰─────────────────────────────────────────────────────────╯
T['formatters()']['default'] = new_set()

--          ╭─────────────────────────────────────────────────────────╮
--          │                     Short formatter                     │
--          ╰─────────────────────────────────────────────────────────╯
T['formatters()']['short'] = new_set()

--          ╭─────────────────────────────────────────────────────────╮
--          │                    Custom formatter                     │
--          ╰─────────────────────────────────────────────────────────╯
T['formatters()']['custom'] = new_set()

return T
