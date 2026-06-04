return {
  {
    "epwalsh/obsidian.nvim",
    version = "*", -- use latest release instead of latest commit
    lazy = false,
    -- ft = "markdown", -- Load globally so commands like ObsidianSearch are available on startup
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    opts = {
      workspaces = {
        {
          name = "personal",
          path = "~/zettelkasten",
        },
      },
      -- Specify the picker to use
      picker = {
        name = "fzf-lua",
      },
      -- Keymaps are defined in config below or handled by the plugin defaults
      -- but we'll add some explicitly for the cheatsheet and ease of use.
      mappings = {
        -- Overrides the 'gf' mapping to work on markdown/obsidian links within the vault.
        ["gf"] = {
          action = function()
            return require("obsidian").util.gf_passthrough()
          end,
          opts = { noremap = false, expr = true, buffer = true },
        },
        -- Toggle check-boxes.
        ["<leader>ch"] = {
          action = function()
            return require("obsidian").util.toggle_checkbox()
          end,
          opts = { buffer = true },
        },
        -- Smart action depending on context, either follow link or toggle checkbox.
        ["<cr>"] = {
          action = function()
            return require("obsidian").util.smart_action()
          end,
          opts = { buffer = true, expr = true },
        },
      },
    },
    config = function(_, opts)
      require("obsidian").setup(opts)

      -- Additional global keymaps for Obsidian
      vim.keymap.set("n", "<leader>on", "<cmd>ObsidianNew<cr>", { desc = "New Obsidian Note" })
      vim.keymap.set("n", "<leader>os", function()
        local client = require("obsidian").get_client()
        require("fzf-lua").grep({
          search = "",
          cwd = client.current_workspace.path,
        })
      end, { desc = "Search Obsidian Notes (Fuzzy)" })
      vim.keymap.set("n", "<leader>ot", "<cmd>ObsidianTags<cr>", { desc = "Search Obsidian Tags" })
      vim.keymap.set("n", "<leader>oo", "<cmd>ObsidianOpen<cr>", { desc = "Open in Obsidian App" })
      vim.keymap.set("n", "<leader>ob", "<cmd>ObsidianBacklinks<cr>", { desc = "Show Backlinks" })
    end,
  },
}
