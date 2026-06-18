return {
	{
		"RedsXDD/neopywal.nvim",
		name = "neopywal",
		lazy = false,
		priority = 1000,
		opts = {
			use_palette = "wallust",
			background = "dark", -- Force using raw colors from wallust
			background_control = false, -- Don't let neopywal manage vim.o.background
		},
		config = function(_, opts)
			require("neopywal").setup(opts)
			vim.cmd.colorscheme("neopywal")
		end,
	},
}
