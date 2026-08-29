-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.g.snacks_animate = false

-- Clipboard exchange with the host over SSH.
-- LazyVim disables the system clipboard when SSH_CONNECTION is set (its
-- default here would be ""). Re-enable it: nvim then uses its tmux clipboard
-- provider (`tmux load-buffer -w` / `refresh-client -l`), which exchanges
-- with the host clipboard via tmux (`set -g set-clipboard on`) and OSC 52 on
-- the Ghostty terminal. This file loads after LazyVim's own options, so the
-- value sticks (LazyVim captures it and restores it on VeryLazy).
vim.opt.clipboard = "unnamedplus"
