return {
	{
		"echasnovski/mini.nvim",
		version = false,
		config = function()
			require("mini.ai").setup()
			require("mini.surround").setup()
			require("mini.comment").setup()
			require("mini.pairs").setup()
			require("mini.statusline").setup()
			require("mini.indentscope").setup()
			require("mini.starter").setup()
			require("mini.files").setup()
			require("mini.icons").setup()

			vim.keymap.set("n", "<leader>e", function()
				require("mini.files").open()
			end, { desc = "Open Mini Files" })
		end,
	},
}
