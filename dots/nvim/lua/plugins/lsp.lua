return {
	{
		"neovim/nvim-lspconfig",
		dependencies = {
			{ "folke/lazydev.nvim", opts = {} },
		},
		config = function()
			-- Neovim 0.11+ uses vim.lsp.config
			local on_attach = function(client, bufnr)
				local map = function(keys, func, desc)
					vim.keymap.set("n", keys, func, { buffer = bufnr, desc = "LSP: " .. desc })
				end

				map("gd", vim.lsp.buf.definition, "[G]oto [D]efinition")
				map("gr", require("fzf-lua").lsp_references, "[G]oto [R]eferences")
				map("gI", vim.lsp.buf.implementation, "[G]oto [I]mplementation")
				map("<leader>D", vim.lsp.buf.type_definition, "Type [D]efinition")
				map("<leader>rn", vim.lsp.buf.rename, "[R]e[n]ame")
				map("<leader>ca", vim.lsp.buf.code_action, "[C]ode [A]ction")
				map("K", vim.lsp.buf.hover, "Hover Documentation")
				map("gD", vim.lsp.buf.declaration, "[G]oto [D]eclaration")
			end

			local servers = {
				lua_ls = {
					settings = {
						Lua = {
							completion = { callSnippet = "Replace" },
							diagnostics = { disable = { "missing-fields" } },
						},
					},
				},
				nil_ls = {
					settings = {
						["nil"] = {
							nix = {
								flake = {
									autoArchive = true,
								},
							},
						},
					},
				},
				tinymist = {},
			}

			for server, config in pairs(servers) do
				config.on_attach = on_attach
				vim.lsp.config(server, config)
				vim.lsp.enable(server)
			end
		end,
	},
}
