{ config, pkgs, ... }:

# Neovim with options, keymaps, and a single plugin: the colour scheme, so
# the editor matches the terminal it runs in.
#
# The two note helpers below belong here rather than with the compositor:
# what they do is edit a file, and the terminal is only the window they need
# in order to do it under a compositor with no other way to start one.
let
  notesDir = "$HOME/documents/notes";
  terminal = "${config.programs.kitty.package}/bin/kitty";
  editor = "${config.programs.neovim.finalPackage}/bin/nvim";

  notesTasks = pkgs.writeShellApplication {
    name = "notes-tasks";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      set -euo pipefail
      file="${notesDir}/tasks.md"
      mkdir -p "$(dirname "$file")"
      touch "$file"
      exec ${terminal} ${editor} "$file"
    '';
  };

  # Pressing the key should be the whole interaction: by the time the window
  # is up the entry already exists, dated, spaced the way CommonMark wants
  # (blank line between a heading and the paragraph under it), with the
  # cursor sitting on the line to type into and insert mode already on.
  #
  # The entry is written by the shell before Neovim starts, not by Neovim
  # itself, so a stamped heading survives quitting without saving and the
  # file on disk is never half-formed.
  notesInbox = pkgs.writeShellApplication {
    name = "notes-inbox";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
    ];
    text = ''
      set -euo pipefail
      file="${notesDir}/inbox.md"
      mkdir -p "$(dirname "$file")"
      touch "$file"

      # What the previous run left behind is trimmed rather than counted on:
      # its two blank lines if the entry was typed into, and the heading as
      # well if it was not. Without this the spacing drifts a line per visit
      # and every abandoned press leaves a dated heading over nothing.
      body=$(awk '
        { line[NR] = $0 }
        END {
          n = NR
          while (n > 0 && line[n] ~ /^[[:space:]]*$/) n--
          if (n > 0 && line[n] ~ /^#+ /) {
            n--
            while (n > 0 && line[n] ~ /^[[:space:]]*$/) n--
          }
          for (i = 1; i <= n; i++) print line[i]
        }
      ' "$file")

      {
        if [ -n "$body" ]; then
          printf '%s\n\n' "$body"
        fi
        printf '## %s\n\n\n' "$(date '+%Y-%m-%d %H:%M')"
      } >"$file.new"
      mv "$file.new" "$file"

      exec ${terminal} ${editor} -c 'normal! G' -c startinsert "$file"
    '';
  };
in
{
  programs.neovim = {
    enable = true;
    plugins = [ pkgs.vimPlugins.monokai-pro-nvim ];
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

      -- Killing the terminal on a file with unsaved changes leaves a swap
      -- file behind, and the next open of that file stops on a recovery
      -- prompt for it. The prompt is only worth its cost to someone who
      -- answers "recover"; the swap file is turned off instead, since
      -- `undofile` above already carries history across sessions and that
      -- is the part actually being missed.
      opt.swapfile = false

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

      -- Same Monokai Pro filters the terminal uses, picked from the same state file
      -- `desktop-theme` writes. Nothing signals a running editor, so each
      -- instance watches that file itself and re-applies on the spot; a
      -- theme switch never needs an editor to be restarted.
      local theme_file = (vim.env.XDG_STATE_HOME or (vim.env.HOME .. "/.local/state"))
        .. "/desktop-theme"

      local function current_theme()
        local handle = io.open(theme_file, "r")
        if not handle then
          return "dark"
        end
        local value = vim.trim(handle:read("l") or "")
        handle:close()
        return value == "light" and "light" or "dark"
      end

      local function apply_theme()
        local theme = current_theme()
        vim.o.background = theme
        vim.cmd.colorscheme(theme == "light" and "monokai-pro-light" or "monokai-pro")
      end

      apply_theme()

      -- Re-armed on every event: the file is normally rewritten in place,
      -- but a replaced inode would otherwise silence the watch for good.
      local uv = vim.uv or vim.loop
      local watcher = uv.new_fs_event()
      local function watch()
        watcher:start(
          theme_file,
          {},
          vim.schedule_wrap(function()
            apply_theme()
            watcher:stop()
            watch()
          end)
        )
      end
      watch()

      local group = vim.api.nvim_create_augroup("jf-defaults", { clear = true })
      vim.api.nvim_create_autocmd("TextYankPost", {
        group = group,
        callback = function() (vim.hl or vim.highlight).on_yank() end,
      })
    '';
  };

  home.packages = [
    notesInbox
    notesTasks
  ];
}
