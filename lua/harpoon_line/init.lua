-- Module definition ==========================================================

local Harpoon = require("harpoon")
local Extensions = require("harpoon.extensions")
local HarpoonLine = {}
local H = {}

HarpoonLine.setup = function(config)
	config = H.setup_config(config)
	H.apply_config(config)

	H.create_autocommands()
	H.create_extensions()
end

HarpoonLine.config = {}

-- Module functionality =======================================================

HarpoonLine.change_list = function(name)
	H.data.list_name = name
	H.update()
end

-- Helper data ================================================================

H.default_config = vim.deepcopy(HarpoonLine.config)

---@class HarpoonLineData
H.data = {
	list_name = nil,
	list_length = 0,
	buffer_idx = -1,
}

-- Helper functionality =======================================================

H.setup_config = function(config)
	vim.validate({ config = { config, "table", true } })
	config = vim.tbl_deep_extend("force", vim.deepcopy(H.default_config), config or {})
	-- vim.validate({})
	return config
end

H.apply_config = function(config)
	HarpoonLine.config = config
end

H.create_autocommands = function()
	local augroup = vim.api.nvim_create_augroup("HarpoonLine", {})

	vim.api.nvim_create_autocmd("User", {
		group = augroup,
		once = true,
		pattern = "HarpoonLineListenerReady",
		callback = function()
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
		[Extensions.event_names.ADD] = function(data)
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
	H.notify()
end

H.notify = function()
	vim.api.nvim_exec_autocmds("User", {
		pattern = "HarpoonLineChanged",
		modeline = false,
		data = H.data,
	})
end

return HarpoonLine
