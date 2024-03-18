# Harpoonline

Create up-to-date [harpoon2] information to be used in a status-line

## TOC
<!--toc:start-->
- [Harpoonline](#harpoonline)
  - [Demo](#demo)
  - [Features](#features)
  - [Requirements](#requirements)
  - [Setup](#setup)
    - [Using lazy.nvim and lualine](#using-lazynvim-and-lualine)
    - [Using mini.deps and mini.statusline](#using-minideps-and-ministatusline)
  - [Configuration](#configuration)
    - [Formatters](#formatters)
      - [The "short" builtin](#the-short-builtin)
      - [The "extended" builtin](#the-extended-builtin)
      - [Modify a builtin](#modify-a-builtin)
      - [Use a custom formatter](#use-a-custom-formatter)
  - [Harpoon lists](#harpoon-lists)
  - [Related plugins](#related-plugins)
  - [Acknowledgements](#acknowledgements)
<!--toc:end-->

## Demo

WIP

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
- a statusline, for example:
  - [mini.statusline]
  - [lualine]
  - [heirline]
  - a custom implementation

## Setup

**Important**: don't forget to call `require('harpoonline').setup()`
to enable the plugin. Without that call, the formatter will return
an empty string.

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
  ---@type string|nil
  icon = '󰀱',

  -- As harpoon's default list is retrieved without a name,
  -- default_list_name configures the name to be displayed
  ---@type string
  default_list_name = '',

  ---@type string
  formatter = 'extended', -- use a builtin formatter

  ---@type fun():string|nil
  custom_formatter = nil, -- use this formatter when supplied
  ---@type fun()|nil
  on_update = nil, -- optional action to perform after update
}
```

*Note*: The icon does not display properly in the browser...

### Formatters

Scenario's:

- A: 3 harpoons, the current buffer is not harpooned
- B: 3 harpoons, the current buffer is harpooned on mark 2

#### The "short" builtin

```lua
Harpoonline.config = {
  formatter = 'short',
}
```

Output A: :anchor:  `[3]`

Output B: :anchor:  `[2|3]`

#### The "extended" builtin

The default

Output A: :anchor:  `1 2 3 -`

Output B: :anchor:  `1 [2] 3 -`

#### Modify a builtin

Builtin formatters: `Harpoonline.formatters`
The corresponding formatter specific options: `Harpoonline.formatter_opts`

Modify "extended":

```lua
local Harpoonline = require("harpoonline")
Harpoonline.setup({
  custom_formatter = Harpoonline.gen_override("extended", {
    indicators = { "j", "k", "l", "h" },
    active_indicators = { "J", "K", "L", "H" },
  }),
})
```

Output A: :anchor:  `j k l -`

Output B: :anchor:  `j K l -`

#### Use a custom formatter

The following data is kept up-to-date internally to be consumed by formatters:

```lua
---@class HarpoonLineData
H.data = {
  --- @type string|nil
  list_name = nil, -- the name of the list in use
  --- @type number|nil
  list_length = 0, -- the length of the list
  --- @type number|nil
  buffer_idx = nil, -- the harpoon index of the current buffer if harpooned
}
```

Example:

```lua
local Harpoonline = require("harpoonline")
Harpoonline.setup({
  custom_formatter = Harpoonline.gen_formatter(
    function(data, _)
      return string.format(
        "%s%s%s",
        "➡️ ",
        data.list_name and string.format("%s ", data.list_name) or "",
        data.buffer_idx and string.format("%d", data.buffer_idx) or "-"
      )
    end,
    {}
  ),
})
```

Output A: :arrow_right:  `-`

Output B: :arrow_right:  `2`

## Harpoon lists

This plugin provides support for working with multiple harpoon lists.

The list in use when Neovim is started is assumed to be the default list

When switching to another list, the plugin needs to be notified
using its custom `HarpoonSwitchedList` event:

```lua
local list_name = nil -- starts with the default

vim.keymap.set("n", "<leader>J", function()
  -- toggle between the current list and list "custom"
  list_name = list_name ~= "custom" and "custom" or nil
  vim.api.nvim_exec_autocmds("User",
    { pattern = "HarpoonSwitchedList", modeline = false, data = list_name })
end, { desc = "Switch harpoon list", silent = true })
```

For a more complete example using two harpoon lists, see [ak.config.editor.harpoon]
in my Neovim configuration.

## Related plugins

[harpoon-lualine]:

- Only for [lualine]
- A single, customizable formatting algorithm
- No caching
- Only supports harpoon's default list

[grapple.nvim]:

- Has a similar dedicated lualine component as [harpoon-lualine]

## Acknowledgements

- @theprimeagen: Harpoon is the most important part of my workflow.
- @echasnovski: The structure of this plugin is heavily based on [mini.nvim]
- @letieu: The `extended` formatter is inspired by plugin [harpoon-lualine]

[harpoon2]: https://github.com/ThePrimeagen/harpoon/tree/harpoon2
[mini.statusline]: https://github.com/echasnovski/mini.statusline
[lualine]: https://github.com/nvim-lualine/lualine.nvim
[heirline]: https://github.com/rebelot/heirline.nvim
[mini.nvim]: https://github.com/echasnovski/mini.nvim
[harpoon-lualine]: https://github.com/letieu/harpoon-lualine
[grapple.nvim]: https://github.com/cbochs/grapple.nvim
[ak.config.editor.harpoon]: https://github.com/abeldekat/nvim_pde/blob/main/lua/ak/config/editor/harpoon.lua
