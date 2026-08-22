{ ... }:

# Neovim with no plugins: options, keymaps, and nothing that has to be
# updated when a plugin ecosystem moves.
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    initLua = ''
      vim.g.mapleader = " "
      vim.g.maplocalleader = " "

      local opt = vim.opt
      opt.breakindent = true
      opt.clipboard = "unnamedplus"
      opt.confirm = true
      opt.cursorline = true
      opt.expandtab = true
      opt.ignorecase = true
      opt.inccommand = "split"
      opt.list = true
      opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
      opt.mouse = "a"
      opt.number = true
      opt.relativenumber = true
      opt.scrolloff = 8
      opt.shiftwidth = 2
      opt.showmode = false
      opt.signcolumn = "yes"
      opt.smartcase = true
      opt.smartindent = true
      opt.splitbelow = true
      opt.splitright = true
      opt.tabstop = 2
      opt.termguicolors = true
      opt.timeoutlen = 400
      opt.undofile = true
      opt.updatetime = 250
      opt.wrap = false

      vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")
      vim.keymap.set("n", "<leader>w", "<cmd>write<CR>", { desc = "Write file" })
      vim.keymap.set("n", "<leader>q", "<cmd>confirm quit<CR>", { desc = "Quit" })
      vim.keymap.set("n", "<C-h>", "<C-w>h", { desc = "Focus left" })
      vim.keymap.set("n", "<C-j>", "<C-w>j", { desc = "Focus down" })
      vim.keymap.set("n", "<C-k>", "<C-w>k", { desc = "Focus up" })
      vim.keymap.set("n", "<C-l>", "<C-w>l", { desc = "Focus right" })
      vim.keymap.set("v", "<", "<gv")
      vim.keymap.set("v", ">", ">gv")

      local group = vim.api.nvim_create_augroup("jf-defaults", { clear = true })
      vim.api.nvim_create_autocmd("TextYankPost", {
        group = group,
        callback = function() (vim.hl or vim.highlight).on_yank() end,
      })
    '';
  };
}
