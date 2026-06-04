-- Sane defaults for Neovim
vim.g.mapleader = " "
vim.g.maplocalleader = " "

local opt = vim.opt

opt.number = true         -- Show line numbers
opt.relativenumber = true -- Relative line numbers
opt.mouse = "a"           -- Enable mouse support
opt.showmode = false      -- Don't show mode since we'll use a statusline
opt.termguicolors = true -- Use GUI colors
opt.clipboard = "unnamedplus" -- Sync with system clipboard
opt.breakindent = true    -- Wrap indent
opt.wrap = true           -- Enable soft wrap
opt.linebreak = true      -- Wrap at word boundaries
opt.undofile = true       -- Save undo history
opt.ignorecase = true     -- Case-insensitive searching
opt.smartcase = true      -- Smart case
opt.signcolumn = "yes"    -- Always show sign column
opt.updatetime = 250      -- Faster completion
opt.timeoutlen = 300      -- Time to wait for a mapped sequence
opt.splitright = true     -- Split vertical window to the right
opt.splitbelow = true     -- Split horizontal window to the bottom
opt.list = true           -- Show certain invisible characters
opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
opt.inccommand = "split"  -- Preview substitutions live
opt.cursorline = true    -- Highlight the current line
opt.scrolloff = 10        -- Minimal number of screen lines to keep above and below the cursor
opt.conceallevel = 2      -- Hide formatting symbols to support Obsidian UI features
opt.background = "dark"    -- Always use dark mode


-- Indentation
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.softtabstop = 2
opt.smartindent = true

