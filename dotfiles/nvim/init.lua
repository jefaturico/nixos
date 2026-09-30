-- System clipboard
vim.opt.clipboard = "unnamedplus"

-- Follow the current file's directory
vim.opt.autochdir = true

-- Line numbers
vim.opt.number = true
vim.opt.relativenumber = true

-- Better searching
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.incsearch = true

-- Indentation
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.smartindent = true

-- Keep some context around the cursor
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8

-- Better splits
vim.opt.splitright = true
vim.opt.splitbelow = true

-- Don't wrap long lines
vim.opt.wrap = false

-- Show whitespace mistakes a little more clearly
vim.opt.list = true
vim.opt.listchars = {
  tab = "→ ",
  trail = "·",
  nbsp = "␣",
}

-- Persistent undo
vim.opt.undofile = true

-- Faster UI updates
vim.opt.updatetime = 250
vim.opt.timeoutlen = 400

-- Confirm instead of failing when closing modified buffers
vim.opt.confirm = true

-- Theming
vim.opt.termguicolors = false

-- Terminal: Esc returns to Normal mode
vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]])

-- Easier split navigation
vim.keymap.set("n", "<C-h>", "<C-w>h")
vim.keymap.set("n", "<C-j>", "<C-w>j")
vim.keymap.set("n", "<C-k>", "<C-w>k")
vim.keymap.set("n", "<C-l>", "<C-w>l")

-- Clear search highlighting
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- LSP shit
vim.keymap.set("n", "gd", vim.lsp.buf.definition)

-- Create missing parent directories on save
vim.api.nvim_create_autocmd("BufWritePre", {
  callback = function(args)
    local dir = vim.fn.fnamemodify(args.file, ":p:h")
    if dir ~= "" then
      vim.fn.mkdir(dir, "p")
    end
  end,
})

-- Remember last cursor position
vim.api.nvim_create_autocmd("BufReadPost", {
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local line_count = vim.api.nvim_buf_line_count(0)

    if mark[1] > 0 and mark[1] <= line_count then
      vim.api.nvim_win_set_cursor(0, mark)
    end
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown", "text", "gitcommit" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
    vim.opt_local.breakindent = true
  end,
})

-- ============================================================
-- Plugin manager
-- ============================================================

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "--branch=stable",
    "https://github.com/folke/lazy.nvim.git",
    lazypath,
  })
end

vim.opt.rtp:prepend(lazypath)


-- ============================================================
-- Plugins
-- ============================================================

require("lazy").setup({

  -- Provides configurations for language servers.
  {
    "neovim/nvim-lspconfig",
  },

  -- Completion UI.
  {
    "saghen/blink.cmp",

    dependencies = {
      "saghen/blink.lib",
    },

    build = function()
      require("blink.cmp").build():pwait()
    end,

    opts = {
      keymap = {
        preset = "default",
      },

      sources = {
        default = {
          "lsp",
        },
      },
    },
  },
  -- Makes Markdown prettier inside Neovim.
{
  "MeanderingProgrammer/render-markdown.nvim",
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "nvim-mini/mini.nvim",
  },

  opts = {
    latex = {
      enabled = true,
      converter = { "utftex", "latex2text" },
      inline = true,
      block = true,
    },
  },
},

})


-- ============================================================
-- Language servers
-- ============================================================

vim.lsp.enable("marksman")
