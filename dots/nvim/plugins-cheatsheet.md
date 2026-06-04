# Neovim Plugin Cheatsheet

This cheatsheet lists the common keybindings for the plugins installed in your Neovim configuration.

## Fzf-lua (Fuzzy Finder)
- `<leader>ff`: Find Files
- `<leader>fg`: Live Grep
- `<leader>fb`: Buffers
- `<leader>fh`: Help Tags

## LSP (Language Server Protocol)
- `gd`: [G]oto [D]efinition
- `gr`: [G]oto [R]eferences
- `gI`: [G]oto [I]mplementation
- `gD`: [G]oto [D]eclaration
- `K`: Hover Documentation
- `<leader>D`: Type [D]efinition
- `<leader>rn`: [R]e[n]ame
- `<leader>ca`: [C]ode [A]ction

## Obsidian.nvim (Notes & Second Brain)
- `<leader>on`: New Obsidian Note
- `<leader>os`: Search Obsidian Notes
- `<leader>ot`: Search Obsidian Tags
- `<leader>oo`: Open in Obsidian App
- `<leader>ob`: Show Backlinks
- `gf`: Follow link under cursor (within vault)
- `<leader>ch`: Toggle checkbox
- `<cr>`: Smart action (follow link or toggle checkbox)

## Mini.nvim (Minimal & Fast Modules)
- `<leader>e`: Open **Mini.Files** (file explorer)
- `gc`: Comment or Uncomment (prefix for motions)
- `sa`: Add surrounding (e.g. `saiw)`) - **Mini.Surround**
- `sd`: Delete surrounding (e.g. `sd)`) - **Mini.Surround**
- `sr`: Replace surrounding (e.g. `sr)"`) - **Mini.Surround**
- `a`: Text object "around" (e.g. `vaf` for around function) - **Mini.Ai**
- `i`: Text object "inside" (e.g. `vif` for inside function) - **Mini.Ai**

## Render-markdown.nvim (UI)
- Automatically renders markdown files with better aesthetics (icons, headers, etc.). No specific keybindings by default, but it improves the visual experience.

---
*Note: Keybindings starting with `<leader>` use the Space key as the default leader.*
