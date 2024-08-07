# Harpoonline

:exclamation: **Update**: This repository has been archived on 2024.07.28

Create up-to-date [harpoon2] information for any place where
that information can be useful. For example, in statuslines and the tabline.

## Demo

<https://github.com/abeldekat/harpoonline/assets/58370433/ec56eeb2-3cbf-46fe-bc9d-633f6aa8bb9b>

*Demo of the features. Using lualine and mini.statusline.*

![1710845846](https://github.com/abeldekat/harpoonline/assets/58370433/9a6ac3fa-2f64-40f1-a3bf-1e5702b49ccc)
*Heirline in AstroNvim v4*

![1710925071](https://github.com/abeldekat/harpoonline/assets/58370433/4b911ed1-428d-4a64-ba9d-f67ba6438ce7)
*Custom statusline in NvChad v2.5*

*Note*: The video demonstrates the first release and will become outdated.

## Features

- Supports multiple [harpoon2] lists.
- Highly configurable: Use or modify default formatters or supply a custom formatter
- Decoupled from status-line: Can be used anywhere.
- Resilience: The formatter will return an empty string when harpoon is not present.
- Performance/efficiency: The data is cached and *only* updated when needed.

*Note*:

Without caching the info needed from harpoon must be retrieved whenever
a status-line updates. Typically, this happens often:

- When navigating inside a buffer
- When editing text inside a buffer

## Requirements

- Latest stable `Neovim` version or nightly
- [harpoon2]
- A statusline. Examples: [mini.statusline], [lualine], [heirline] or a custom implementation

## Setup

**Important**: don't forget to call `require('harpoonline').setup()`
to enable the plugin. Without that call, the formatter will return
an empty string.

### Using lazy.nvim and lualine

```lua
{
    "nvim-lualine/lualine.nvim",
    dependencies =  { "abeldekat/harpoonline", version = "*" },
    config = function()
      local Harpoonline = require("harpoonline")
      Harpoonline.setup({
        on_update = function() require("lualine").refresh() end,
      })

      local lualine_c = { Harpoonline.format, "filename" }
      require("lualine").setup({ sections = { lualine_c = lualine_c } })
    end,
}
```

### Using mini.deps and mini.statusline

```lua
local function config()
  local MiniStatusline = require("mini.statusline")
  local HarpoonLine= require("harpoonline")

  local function isnt_normal_buffer() return vim.bo.buftype ~= "" end
  local function harpoon_highlight() -- using mini.hipatterns
    return Harpoonline.is_buffer_harpooned() and "MiniHipatternsHack"
      or "MiniStatuslineFilename"
  end
  local function section_harpoon(args)
    if MiniStatusline.is_truncated(args.trunc_width) or isnt_normal_buffer() then
      return ""
    end
    return Harpoonline.format()
  end
  local function active() -- Hook, see mini.statusline setup
    -- copy any lines from mini.statusline, H.default_content_active:
    local harpoon_data = section_harpoon({ trunc_width = 75 })
    return MiniStatusline.combine_groups({
      -- copy any lines from mini.statusline, H.default_content_active:
      { hl = H.harpoon_highlight(), strings = { harpoon_data } },
    })
  end

  HarpoonLine.setup({
    on_update = function()
      vim.wo.statusline = "%{%v:lua.MiniStatusline.active()%}"
    end
  })
  MiniStatusline.setup({set_vim_settings = false, content = { active = active }})
end

local MiniDeps = require("mini.deps")
local add, now = MiniDeps.add, MiniDeps.now
now(function()
  add({
    source = "echasnovski/mini.statusline",
    depends = {{ source = "abeldekat/harpoonline", checkout = "stable" }}
  })
  config()
end
```

A custom setup for mini.statusline can be found in [ak.config.ui.mini_statusline]

## Configuration

The following configuration is implied when calling `setup` without arguments:

```lua
---@class HarpoonLineConfig
Harpoonline.config = {
  -- other candidates: "󰀱", "", "󱡅", "󰶳"
  -- default: icon nf-md-hook in nerdfont, unicode f06e2:
  ---@type string
  icon = '󰛢', -- An empty string disables showing the icon

  -- Harpoon:list(), when name is nil, retrieves the default list:
  -- default_list_name: Configures the display name for the default list.
  ---@type string
  default_list_name = '',

  ---@type "default" | "short"
  formatter = 'default', -- use a built-in formatter

  formatter_opts = {
    default = {
      inactive = ' %s ', -- including spaces
      active = '[%s]',
      -- Max number of slots to display:
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
```

*Note*: The icon does not display properly in the browser...

## Formatters

Scenario's:

- A: 3 marks, the current buffer is not harpooned
- B: 3 marks, the current buffer is harpooned on mark 2

*Note*: More examples can be found in [ak.config.ui.harpoonline]

### The "default" built-in

Default options: `config.formatter_opts.default`

Output A: 󰛢  ` 1  2  3 `

Output B: 󰛢  ` 1 [2] 3 `

**Note**: Five marks, the fifth mark is the active buffer:

Output B: 󰛢  ` 1  2  3  4 […] `

### The "short" built-in

Add to the config: `formatter = 'short'`. Default options: `config.formatter_opts.short`

Output A: 󰛢  `[3]`

Output B: 󰛢  `[2|3]`

### Customize a built-in

```lua
Harpoonline.setup({
  -- config
  formatter_opts = {
    default = { -- remove all spaces...
      inactive = "%s",
      active = "[%s]",
    },
  },
  -- more config
})
```

Output A: 󰛢  `123`

Output B: 󰛢  `1[2]3`

### Use a custom formatter

The following data is kept up-to-date internally, to be processed by formatters:

```lua
---@class HarpoonlineData
---@field list_name string|nil -- the name of the current list
---@field items HarpoonItem[] -- the items of the current list
---@field active_idx number|nil -- the harpoon index of the current buffer
```

#### Example "very short"

```lua
Harpoonline.setup({
  -- config
  ---@param data HarpoonlineData
  ---@param opts HarpoonLineConfig
  ---@return string
  custom_formatter = function(data,opts)
    return string.format( -- very short, without the length of the harpoon list
      "%s%s%s",
      opts.icon .. " ",
      data.list_name and string.format("%s ", data.list_name) or "",
      data.active_idx and string.format("%d", data.active_idx) or "-"
    )
  end
  -- more config
})
```

Output A: 󰛢  `-`

Output B: 󰛢  `2`

#### Example "letters"

```lua
Harpoonline.setup({
  -- config
  ---@param data HarpoonlineData
  ---@param opts HarpoonLineConfig
  ---@return string
  custom_formatter = function(data, opts)
    local letters = { "j", "k", "l", "h" }
    local idx = data.active_idx
    local slot = 0
    local slots = vim.tbl_map(function(letter)
      slot = slot + 1
      return idx and idx == slot and string.upper(letter) or letter
    end, vim.list_slice(letters, 1, math.min(#letters, #data.items)))

    local name = data.list_name and data.list_name or opts.default_list_name
    local header = string.format("%s%s%s", opts.icon, name == "" and "" or " ", name)
    return header .. " " .. table.concat(slots)
  end,
  -- more config
})
```

Output A: 󰛢  `jkl`

Output B: 󰛢  `jKl`

*Note*:

- It is possible to also use inner highlights in the formatter function.
See the example recipe for NvChad.
- It is possible to use the `harpoon` information inside each `data.items`

## Harpoon lists

This plugin supports working with multiple harpoon lists.
The list in use when Neovim is started is assumed to be the default list

**Important**:

The plugin needs to be notified when switching to another list
using its custom `HarpoonSwitchedList` event:

```lua
 -- Starts with the default. Use this variable in harpoon:list(list_name)
local list_name = nil

vim.keymap.set("n", "<leader>J", function()
  -- toggle between the default list(nil) and list "custom"
  list_name = list_name ~= "custom" and "custom" or nil
  vim.api.nvim_exec_autocmds("User",
    { pattern = "HarpoonSwitchedList", modeline = false, data = list_name })
end, { desc = "Switch harpoon list", silent = true })
```

A complete setup using two harpoon lists can be found in [ak.config.editor.harpoon]

## Recipes

### Heirline

Basic example:

```lua
local Harpoonline = require "harpoonline"
Harpoonline.setup({
  on_update = function() vim.cmd.redrawstatus() end
})
local HarpoonComponent = {
  provider = function() return " " .. Harpoonline.format() .. " " end,
  hl = function()
    if Harpoonline.is_buffer_harpooned() then 
      return "MiniHipatternsHack"-- example using mini.hipatterns
    end
  end,
}
-- A minimal statusline:
require("heirline").setup({ statusline = { HarpoonComponent }})
```

<details>
<summary>A proof of concept for AstroNvim v4</summary>

```lua
{
  "rebelot/heirline.nvim",
  dependencies = "abeldekat/harpoonline",
  config = function(plugin, opts)
    local Status = require "astroui.status"
    local Harpoonline = require "harpoonline"
    Harpoonline.setup {
      on_update = function() vim.cmd.redrawstatus() end,
    }
    local HarpoonComponent = Status.component.builder {
      {
        provider = function()
          local line = Harpoonline.format()
          return Status.utils.stylize(line, { padding = { left = 1, right = 1 }})
        end,
        hl = function()
          if Harpoonline.is_buffer_harpooned() then
              return { bg = "command", fg = "bg" }
          end
        end,
      },
    }
    table.insert(opts.statusline, 4, HarpoonComponent) -- after file_info component
    require "astronvim.plugins.configs.heirline"(plugin, opts)
  end,
}
```

</details>

### NvChad statusline

<details>
<summary>A proof of concept for NvChad v2.5</summary>

```lua
---@type ChadrcConfig
local M = {} -- nvchad starter: lua.chadrc.lua

-- Add to config.plugins:
-- {
--     "nvchad/ui",
--     dependencies = {
--       "abeldekat/harpoonline",
--       config = function()
--         require("harpoonline").setup {
--           on_update = function() vim.cmd.redrawstatus() end,
--         }
--       end,
--     },
-- }

M.ui = {
  theme = "flexoki-light",

  statusline = {
    theme = "vscode",
    separator_style = "default",
    -- Copy local "orders.vscode" from nvchad.stl.utils(plugin nvchad/ui)
    -- Add string "harpoon" before "file"
    order = { "mode", "harpoon", "file", "diagnostics", "git",
      "%=", "lsp_msg", "%=", "lsp", "cursor", "cwd" },
    modules = {
      -- Add a custom harpoon module, using the file background.
      harpoon = function()
        return "%#St_file_bg# " .. require("harpoonline").format() .. " "
      end,
    },
  },
}

return M
```

</details>

## Related plugins

[harpoon-lualine]

- Dedicated to [lualine]
- A single, customizable formatting algorithm
- No caching
- No support for other lists than the default

## Acknowledgements

- @theprimeagen: Harpoon is the most important part of my workflow.
- @echasnovski: The structure of this plugin is heavily based on [mini.nvim]

[harpoon2]: https://github.com/ThePrimeagen/harpoon/tree/harpoon2
[lualine]: https://github.com/nvim-lualine/lualine.nvim
[mini.statusline]: https://github.com/echasnovski/mini.statusline
[heirline]: https://github.com/rebelot/heirline.nvim
[mini.nvim]: https://github.com/echasnovski/mini.nvim
[harpoon-lualine]: https://github.com/letieu/harpoon-lualine
[ak.config.editor.harpoon]: https://github.com/abeldekat/nvim_pde/blob/main/lua/ak/config/editor/harpoon.lua
[ak.config.ui.harpoonline]: https://github.com/abeldekat/nvim_pde/blob/main/lua/ak/config/ui/harpoonline.lua
[ak.config.ui.mini_statusline]: https://github.com/abeldekat/nvim_pde/blob/main/lua/ak/config/ui/mini_statusline.lua
