local M = {}

local json = require("utils.json")
local notifier = require("utils.notify")
local path = require("utils.path")
local map = require("utils.ds.map")
local array = require("utils.ds.array")

-- import telescope
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local telescope_config = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

-- some const values
local cache_file = ".bookmarks.json" -- Default stotage file

function M.init()
	vim.cmd("delmarks a-zA-Z")
	local reg_file = vim.lsp.buf.list_workspace_folders()[1] .. "/" .. cache_file
	os.remove(reg_file)
	local initial = {
		index = 0,
		registry = {}, -- {name={index=0, mark='A'}}
		free = {
			"A",
			"B",
			"C",
			"D",
			"E",
			"F",
			"G",
			"H",
			"I",
			"J",
			"K",
			"L",
			"M",
			"N",
			"O",
			"P",
			"Q",
			"R",
			"S",
			"T",
			"U",
			"V",
			"W",
			"X",
			"Y",
			"Z",
		},
		alloc = {},
	}
	-- vim.fn.JsonDumpF(reg_file, initial)
	assert(json.dump(reg_file, initial), "Write BookMark Initial Data to cache file Failed")
end

function M.add()
	-- if annotation existed, throw an error, don't update
	-- if annotation not existed, then add
	local reg_file = vim.lsp.buf.list_workspace_folders()[1] .. "/" .. cache_file

	local res = path.exists(reg_file)
	notifier.notify(vim.inspect(res), "info", "hehe")
	if path.exists(reg_file) == false then
		M.init()
	end

	local registry = json.load(reg_file)
	if registry == nil then
		return
	end

	vim.ui.input({ prompt = "Input BookMark Annotation" }, function(bk_name)
		local title = "Register BookMarks" -- Define notify tile
		local message_success = title .. " Successfully!"
		local message_failed = title .. " Failed: "

		if bk_name == nil then
			return notifier.notify(message_failed .. "Cancel ", notifier.Level.info, title)
		end

		if map.has_key(registry["registry"], bk_name) == false then
			notifier.notify(message_failed .. "bookmark" .. bk_name .. "has existed", notifier.Level.error, title)
			return
		end

		-- the number of must be less than 10
		if map.empty(registry["free"]) then
			notifier.notify(message_failed .. "too many bookmarks", notifier.Level.warn, title)
			return
		end

		if bk_name == nil then
			notifier.notify(message_failed .. "canceled", notifier.Level.warn, title)
		end

		-- pop mark from freelist,then push the mark into allocat list

		local mark = array.queue_pop(registry["free"])
		registry["free"].push()
		array.queue_push(registry["alloc"], mark)

		-- set bookmark
		vim.cmd("normal! m" .. mark)
		local row, _, _, buffername = unpack(vim.api.nvim_get_mark(mark, {}))

		map.set(
			registry["registry"],
			bk_name,
			{ index = registry.index, mark = mark, filename = buffername, lnum = row }
		)

		-- inc index automatically
		registry.index = registry.index + 1

		-- update storage
		-- vim.fn.JsonDumpF(reg_file, registry)
		json.dump(reg_file, registry)

		notifier.notify(message_success, notifier.Level.info, title)
	end)
end

function M.operator()
	local title = "BookMarks" -- Define notify tile
	local reg_file = vim.lsp.buf.list_workspace_folders()[1] .. "/" .. cache_file

	if path.exists(reg_file) == true then
		M.init()
		notifier.notify("BookMarks is Empty", "warn", title)
	end

	-- local registry = vim.fn.JsonLoadF(reg_file)
	local registry = json.load(reg_file)
	if registry == nil then
		return
	end

	local bk_key_list = map.keys(registry["registry"])

	local opts = { layout_config = {
		prompt_position = "top",
		preview_width = 0.7,
	} }
	pickers
		.new(opts, {
			prompt_title = "Bookmarks",
			finder = finders.new_table({
				results = bk_key_list,
				entry_maker = function(entry)
					local bk_item = map.get(registry["registry"], entry[1])

					local display = "[" .. tostring(bk_item.index) .. "] " .. entry[1]
					return {
						value = entry[1],
						mark = bk_item.mark,
						display = display,
						ordinal = tostring(bk_item.index),
						filename = bk_item.filename,
						lnum = bk_item.lnum,
					}
				end,
			}),
			sort = telescope_config.generic_sorter(opts),
			previewer = telescope_config.qflist_previewer(opts),
			attach_mappings = function(prompt_bufnr, map)
				map("n", "d", function() -- delete bookmark
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry()
					-- delete marks from cache
					map.remove(registry["registry"], selection.value)
					-- delete from vim register
					vim.api.nvim_del_mark(selection.mark)

					array.delete(registry["alloc"], selection.mark)
					array.queue_push(registry["free"], selection.mark)

					assert(json.dump(reg_file, registry))
					-- vim.fn.JsonDumpF(reg_file, registry)
					notifier.notify(
						"Delelte Bookmark: " .. selection.value .. " Successfully",
						notifier.Level.info,
						title
					)
				end)
				map("n", "r", function() -- rename bookmark
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry()
					vim.ui.input({ prompt = "Rename BookMark" }, function(new_name)
						map.update_key(registry["registry"], selection.value, new_name)

						assert(json.dump(reg_file, registry))
					end)
				end)
				map("i", "<CR>", function() -- selected and jump to bookmark
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry()
					vim.cmd("normal! '" .. selection.mark)
				end)
				map("n", "<CR>", function() -- selected and jump to bookmark
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry()
					vim.cmd("normal! '" .. selection.mark)
				end)

				return true
			end,
		})
		:find()
end

function M.clean_all()
	local reg_file = vim.lsp.buf.list_workspace_folders()[1] .. "/" .. cache_file
	if path.exists(reg_file) == true then
		os.remove(reg_file)
	end
end

return M
