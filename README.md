# Harpoonline

Create up-to-date [harpoon2] information to be used in a status-line

## Demo

WIP

## Features

- Supports multiple [harpoon2] lists.
- Highly configurable: Use or modify default formatters or supply a custom formatter
- Decoupled from status-line: Can be used anywhere.
- Performance/efficiency: The data is cached and *only* updated when needed.

*Note*:

Without caching the info needed from harpoon must be retrieved whenever
a status-line updates. Typically, this happens often:

- When navigating inside a buffer
- When editing text inside a buffer

*Note*:

The following data is kept up-to-date internally to be consumed by formatters:

```lua
---@class HarpoonLineData
H.data = {
  list_name = nil, -- the name of the list in use
  list_length = 0, -- the length of the list
  buffer_idx = -1, -- the harpoon index of the current buffer if harpooned
}
```

## Requirements

- Latest stable `Neovim` version or nightly
- [harpoon2]
- a statusline, for example:
  - [mini.statusline]
  - [lualine]
  - [heirline]
  - a custom implementation

## Setup

### Using lazy.nvim and lualine

```lua
{
    "nvim-lualine/lualine.nvim",
    dependencies =  "abeldekat/harpoonline",
    config = function()
      local Harpoonline = require("harpoonline").setup() -- using default config
      local lualine_c = { Harpoonline.format, "filename" }

      require("lualine").setup({
        sections = {
          lualine_c = lualine_c,
        },
      })
    end,
}
```

### Using mini.deps and mini.statusline

```lua
local function config()
  local MiniStatusline = require("mini.statusline")
  local HarpoonLine= require("harpoonline")


  local function isnt_normal_buffer()
    return vim.bo.buftype ~= ""
  end
  local function harpoon_highlight() -- example using mini.hipatterns:
    return Harpoonline.is_buffer_harpooned() and "MiniHipatternsHack"
      or "MiniStatuslineFilename" ----> highlight when a buffer is harpooned
  end
  local function section_harpoon(args)
    if MiniStatusline.is_truncated(args.trunc_width)
      or isnt_normal_buffer() then
      return ""
    end
    return Harpoonline.format() ---->  produce the info
  end
  local function active() -- adding a harpoon section:
    -- copy lines from mini.statusline, H.default_content_active:
    -- ...
    local harpoon_data = section_harpoon({ trunc_width = 75 })
    -- ...
  
    return MiniStatusline.combine_groups({
      -- copy lines from mini.statusline, H.default_content_active:
      -- ...
      { hl = H.harpoon_highlight(), strings = { harpoon_data } },
      -- ...
    })
  end

  HarpoonLine.setup({
    on_update = function()
      vim.wo.statusline = "%!v:lua.MiniStatusline.active()"
    end
  })
  MiniStatusline.setup({
    set_vim_settings = false,
    content = { active = active },
  })
end

local MiniDeps = require("mini.deps")
local add, now = MiniDeps.add, MiniDeps.now
now(function()
  add({ source = "echasnovski/mini.statusline", depends = {"abeldekat/harpoonline"}})
  config()
end
```

## Configuration

The following configuration is implied when calling `setup` without arguments:

```lua
---@class HarpoonLineConfig
Harpoonline.config = {
  icon = '󰀱', --   󱡅
  default_list_name = '',
  formatter = 'extended', -- the default formatter

  ---@type fun():string|nil
  custom_formatter = nil, -- use this formatter when supplied
  ---@type fun()|nil
  on_update = nil,
}
```

### Formatters

- Situation A: 3 harpoons, the current buffer is not harpooned
- Situation B: 3 harpoons, the current buffer is harpooned on index 2

#### Simple, builtin

```lua
Harpoonline.config = {
  formatter = 'simple',
}
```

Output A: `󰀱 [3]`

Output B: `󰀱 [2|3]`

#### Extended, builtin

The default

Output A: `󰀱 1 2 3 -`

Output B: `󰀱 1 [2] 3 -`

#### Modify a builtin

WIP

#### Use a custom formatter

WIP

## Harpoon lists

WIP

## Acknowledgements

- @theprimeagen: Harpoon is the most important part of my workflow.
- @echasnovski: The structure of this plugin is heavily based on [mini.nvim]
- @letieu: The `extended` formatter is based on plugin [harpoon-lualine]

## Related plugins

[harpoon-lualine]:

- Only for [lualine]
- A single, customizable formatting algorithm
- No caching
- Only supports harpoon's default list

[grapple.nvim]:

- Has a similar dedicated lualine component as [harpoon-lualine]

[harpoon2]: https://github.com/ThePrimeagen/harpoon/tree/harpoon2
[mini.statusline]: https://github.com/echasnovski/mini.statusline
[lualine]: https://github.com/nvim-lualine/lualine.nvim
[heirline]: https://github.com/rebelot/heirline.nvim
[mini.nvim]: https://github.com/echasnovski/mini.nvim
[harpoon-lualine]: https://github.com/letieu/harpoon-lualine
[grapple.nvim]: https://github.com/cbochs/grapple.nvim
