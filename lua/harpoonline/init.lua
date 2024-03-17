-- Module definition ==========================================================

-- icons "󰀱", "", "󱡅"
local Harpoon = require("harpoon")
local Extensions = require("harpoon.extensions")
local Harpoonline = {}
local H = {}

Harpoonline.setup = function(config)
	config = H.setup_config(config)
	H.apply_config(config)

	H.create_autocommands()
	H.create_extensions()
	return Harpoonline
end

Harpoonline.formatters = {
	simple = function(data, opts)
		return string.format(
			"%s %s[%s%d]",
			opts.icon,
			data.list_name and data.list_name or opts.default_list_name,
			data.buffer_idx > 0 and string.format("%s|", data.buffer_idx) or "",
			data.list_length
		)
	end,
	extended = function(data, opts)
		--          ╭─────────────────────────────────────────────────────────╮
		--          │             credits letieu/harpoon-lualine              │
		--          ╰─────────────────────────────────────────────────────────╯
		local name = string.format("%s %s", opts.icon, data.list_name and data.list_name or opts.default_list_name)
		if data.list_length == 0 then
			return name
		end

		-- local length = math.min(data.list_length, #opts.indicators)
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
		return name .. " " .. table.concat(status, " ")
	end,
}

Harpoonline.config = {
	-- See H.default_formatter
	formatter = nil,
	-- Optional, example: ministatusline.set_active
	on_update = function() end,
}

-- Module functionality =======================================================

Harpoonline.gen_formatter = function(formatter, opts)
	return function()
		return formatter(H.data, opts)
	end
end

Harpoonline.is_buffer_harpooned = function()
	return H.data.buffer_idx > 0
end

-- Helper data ================================================================

H.default_config = vim.deepcopy(Harpoonline.config)

---@class HarpoonLineData
H.data = {
	list_name = nil, -- the default list
	list_length = 0,
	buffer_idx = -1,
}

-- Helper functionality =======================================================

H.setup_config = function(config)
	vim.validate({ config = { config, "table", true } })
	config = vim.tbl_deep_extend("force", vim.deepcopy(H.default_config), config or {})

	vim.validate({ formatter = { config.formatter, "function", true } })
	vim.validate({ on_update = { config.on_update, "function" } })
	return config
end

H.apply_config = function(config)
	if config.formatter == nil then
		config.formatter = H.default_formatter
	end
	Harpoonline.config = config
end

H.get_config = function()
	return Harpoonline.config
end

H.create_autocommands = function()
	local augroup = vim.api.nvim_create_augroup("HarpoonLine", {})

	vim.api.nvim_create_autocmd("User", {
		group = augroup,
		pattern = "HarpoonSwitchedList",
		callback = function(event)
			H.data.list_name = event.data
			H.update()
		end,
	})

	vim.api.nvim_create_autocmd({ "BufEnter" }, {
		group = augroup,
		pattern = "*",
		callback = function()
			H.update()
		end,
	})
end

H.get_list = function()
	return Harpoon:list(H.data.list_name)
end

H.buffer_idx = function()
	-- For more information see ":h buftype"
	local not_found = -1

	if vim.bo.buftype ~= "" then
		return not_found
	end -- not a normal buffer

	local current_file = vim.fn.expand("%:p:.")
	local marks = H.get_list().items
	for idx, item in ipairs(marks) do
		if item.value == current_file then
			return idx
		end
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
	H.get_config().on_update()
end

-- Harpoonline.gen_formatter(Harpoonline.formatters.simple, { icon = "", default_list_name = "-" }),
H.default_formatter = Harpoonline.gen_formatter(Harpoonline.formatters.extended, {
	icon = "󰀱",
	default_list_name = "", -- harpoon's default list is nil...
	indicators = { "1", "2", "3", "4" },
	active_indicators = { "[1]", "[2]", "[3]", "[4]" },
	empty_slot = "-",
})

return Harpoonline
