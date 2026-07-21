local notes_dir = vim.fn.expand("~/documents/notes")

local function notify_missing_cosma()
	vim.notify("Cosma is not installed. Install it with: npm install @graphlab-fr/cosma -g", vim.log.levels.WARN)
end

local function find_cosma_root()
	local current = vim.api.nvim_buf_get_name(0)
	local start = current ~= "" and vim.fs.dirname(current) or vim.uv.cwd()
	local configs = vim.fs.find("config.yml", { path = start, upward = true, limit = 1 })
	if configs[1] then
		return vim.fs.dirname(configs[1])
	end

	if vim.uv.fs_stat(vim.fs.joinpath(notes_dir, "config.yml")) then
		return notes_dir
	end

	return nil
end

local function strip_yaml_string(value)
	value = vim.trim(value)
	value = value:gsub("^['\"]", ""):gsub("['\"]$", "")
	return value
end

local function cosma_export_target(root)
	local config = vim.fs.joinpath(root, "config.yml")
	local ok, lines = pcall(vim.fn.readfile, config)
	if not ok then
		return root
	end

	for _, line in ipairs(lines) do
		local value = line:match("^%s*export_target:%s*(.-)%s*$")
		if value then
			value = strip_yaml_string(value)
			if value ~= "" then
				if vim.startswith(value, "/") then
					return value
				end
				return vim.fs.joinpath(root, value)
			end
			return root
		end
	end

	return root
end

local function generate_cosma_graph(open_after)
	if vim.fn.executable("cosma") == 0 then
		notify_missing_cosma()
		return
	end

	local cwd = find_cosma_root()
	if not cwd then
		vim.notify(
			"Cosma needs config.yml. Run Home Manager to create ~/documents/notes/config.yml.",
			vim.log.levels.WARN
		)
		return
	end

	vim.notify("Generating Cosma graph...", vim.log.levels.INFO)

	vim.system({ "cosma", "modelize" }, { cwd = cwd, text = true }, function(result)
		vim.schedule(function()
			if result.code ~= 0 then
				vim.notify(
					result.stderr ~= "" and result.stderr or "Cosma graph generation failed",
					vim.log.levels.ERROR
				)
				return
			end

			vim.notify("Cosma graph generated", vim.log.levels.INFO)
			if open_after then
				local graph = vim.fs.joinpath(cosma_export_target(cwd), "cosmoscope.html")
				if vim.uv.fs_stat(graph) then
					vim.ui.open(graph)
				else
					vim.notify("Cosma finished, but cosmoscope.html was not found", vim.log.levels.WARN)
				end
			end
		end)
	end)
end

local function insert_wiki_link(path)
	local title = vim.fn.fnamemodify(path, ":t:r")
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col, { "[[" .. title .. "]]" })
end

local function pick_note_link()
	require("fzf-lua").files({
		cwd = notes_dir,
		prompt = "Notes> ",
		actions = {
			default = function(selected, opts)
				if selected[1] then
					local entry = require("fzf-lua.path").entry_to_file(selected[1], opts)
					local path = entry.path
					if not vim.startswith(path, "/") then
						path = vim.fs.joinpath(notes_dir, path)
					end
					insert_wiki_link(path)
				end
			end,
		},
	})
end

vim.api.nvim_create_user_command("CosmaGraph", function()
	generate_cosma_graph(false)
end, { desc = "Generate Cosma graph for the current notes project" })

vim.api.nvim_create_user_command("CosmaGraphOpen", function()
	generate_cosma_graph(true)
end, { desc = "Generate and open Cosma graph for the current notes project" })

vim.api.nvim_create_user_command("ZettelLink", pick_note_link, {
	desc = "Fuzzy-pick a Markdown note and insert a wiki link",
})

vim.api.nvim_create_autocmd("FileType", {
	pattern = "markdown",
	callback = function(event)
		local map = function(keys, rhs, desc)
			vim.keymap.set("n", keys, rhs, { buffer = event.buf, desc = desc })
		end

		map("<leader>zl", pick_note_link, "Insert Markdown Note Link")
		map("<leader>zg", "<cmd>CosmaGraph<cr>", "Generate Cosma Graph")
		map("<leader>zG", "<cmd>CosmaGraphOpen<cr>", "Generate and Open Cosma Graph")
		map("<leader>zd", "<cmd>LspToday<cr>", "Open Daily Note")
	end,
})
