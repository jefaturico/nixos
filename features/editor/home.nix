{ pkgs, ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    plugins = with pkgs.vimPlugins; [
      fzf-lua
      nvim-lspconfig
      (nvim-treesitter.withPlugins (
        parsers: with parsers; [
          bash
          c
          lua
          markdown
          markdown_inline
          nix
          python
          query
          toml
          vim
          vimdoc
        ]
      ))
    ];

    initLua = ''
      vim.g.mapleader = " "
      vim.g.maplocalleader = " "

      local opt = vim.opt
      opt.breakindent = true
      opt.clipboard = "unnamedplus"
      opt.completeopt = { "menuone", "noselect", "popup" }
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
        callback = function() vim.highlight.on_yank() end,
      })
      vim.api.nvim_create_autocmd("BufWritePre", {
        group = group,
        callback = function(event)
          if vim.bo[event.buf].buftype == "" then
            vim.lsp.buf.format({ bufnr = event.buf, timeout_ms = 1000 })
          end
        end,
      })

      local runtime_dir = vim.env.XDG_RUNTIME_DIR
      if runtime_dir then
        local ok, server = pcall(
          vim.fn.serverstart,
          runtime_dir .. "/jf-nvim-" .. vim.fn.getpid() .. ".sock"
        )
        if ok then vim.g.fzf_lua_server = server end
      end

      vim.g.tinted_background_transparent = 1
      local state_home = vim.env.XDG_STATE_HOME or vim.fn.expand("~/.local/state")
      local tinty_theme = state_home .. "/tinted-theming/neovim-theme"
      local transparent_groups = {
        "Normal",
        "NormalNC",
        "EndOfBuffer",
        "MsgArea",
        "NonText",
        "SignColumn",
      }
      local function enforce_transparency()
        for _, name in ipairs(transparent_groups) do
          local highlight = vim.api.nvim_get_hl(0, { name = name, link = false })
          highlight.bg = nil
          highlight.ctermbg = nil
          vim.api.nvim_set_hl(0, name, highlight)
        end
      end
      local function load_tinty()
        if vim.fn.filereadable(tinty_theme) == 1 then
          local theme = vim.trim(vim.fn.readfile(tinty_theme)[1] or "")
          if theme ~= "" then
            local ok, error_message = pcall(vim.cmd.colorscheme, theme)
            if not ok then vim.notify(error_message, vim.log.levels.WARN) end
          end
        end
        enforce_transparency()
      end
      load_tinty()

      vim.api.nvim_create_autocmd("ColorScheme", {
        group = group,
        callback = enforce_transparency,
      })

      vim.api.nvim_create_autocmd("Signal", {
        group = group,
        pattern = "SIGUSR1",
        callback = load_tinty,
      })
      vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = "TintyThemeChanged",
        callback = load_tinty,
      })

      require("nvim-treesitter").setup({})
      vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = { "bash", "c", "lua", "markdown", "nix", "python", "toml", "vim" },
        callback = function()
          pcall(vim.treesitter.start)
          vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end,
      })
      local fzf = require("fzf-lua")
      fzf.setup({ "fzf-native" })
      vim.keymap.set("n", "<leader>ff", fzf.files, { desc = "Find files" })
      vim.keymap.set("n", "<leader>fg", fzf.live_grep, { desc = "Find text" })
      vim.keymap.set("n", "<leader>fb", fzf.buffers, { desc = "Find buffers" })
      vim.keymap.set("n", "<leader>fh", fzf.helptags, { desc = "Find help" })
      vim.keymap.set("n", "gd", vim.lsp.buf.definition, { desc = "Go to definition" })
      vim.keymap.set("n", "gr", fzf.lsp_references, { desc = "Find references" })
      vim.keymap.set("n", "K", vim.lsp.buf.hover, { desc = "Hover documentation" })
      vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, { desc = "Rename symbol" })
      vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, { desc = "Code action" })

      vim.lsp.enable({ "lua_ls", "markdown_oxide", "nil_ls", "ruff", "tinymist" })
    '';
  };
}
