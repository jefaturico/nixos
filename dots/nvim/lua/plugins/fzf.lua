return {
	{
		"ibhagwan/fzf-lua",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		config = function()
			require("fzf-lua").setup({
				"fzf-native",
				winopts = {
					height = 0.85,
					width = 0.80,
					preview = {
						layout = "vertical",
					},
				},
			})
			vim.keymap.set("n", "<leader>ff", "<cmd>FzfLua files<CR>", { desc = "Find Files" })
			vim.keymap.set("n", "<leader>fg", "<cmd>FzfLua live_grep<CR>", { desc = "Live Grep" })
			vim.keymap.set("n", "<leader>fb", "<cmd>FzfLua buffers<CR>", { desc = "Buffers" })
			vim.keymap.set("n", "<leader>fh", "<cmd>FzfLua help_tags<CR>", { desc = "Help Tags" })
		end,
	},
}
