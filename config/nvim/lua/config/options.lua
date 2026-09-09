-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.g.snacks_animate = false

-- Clipboard exchange with the host. There is no SSH anymore (sessions are
-- docker exec'd in from a host-side tmux pane, so SSH_CONNECTION is never set
-- and LazyVim's SSH handling never kicks in). Keep unnamedplus so yank/paste
-- reaches the host clipboard via OSC 52 relayed by host-side tmux
-- (`set -g set-clipboard on`) on the Ghostty terminal. This file loads after
-- LazyVim's own options, so the value sticks (LazyVim captures it and
-- restores it on VeryLazy).
vim.opt.clipboard = "unnamedplus"
