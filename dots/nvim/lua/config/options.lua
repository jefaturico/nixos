-- Sane defaults for Neovim
vim.g.mapleader = " "
vim.g.maplocalleader = " "

local opt = vim.opt

opt.number = true
opt.relativenumber = true
opt.mouse = "a"
opt.showmode = false
opt.termguicolors = true
opt.clipboard = "unnamedplus"
opt.breakindent = true
opt.wrap = true
opt.linebreak = true
opt.undofile = true
opt.ignorecase = true
opt.smartcase = true
opt.signcolumn = "yes"
opt.updatetime = 250
opt.timeoutlen = 300
opt.splitright = true
opt.splitbelow = true
opt.list = true
opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
opt.inccommand = "split"
opt.cursorline = true
opt.scrolloff = 10        -- Minimal number of screen lines to keep above and below the cursor
opt.conceallevel = 2      -- Hide formatting symbols to support Obsidian UI features
opt.background = "dark"

-- Indentation
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.softtabstop = 2
opt.smartindent = true

