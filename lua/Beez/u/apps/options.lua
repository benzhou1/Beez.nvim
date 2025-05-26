local M = {}

function M.common()
  -- Set <space> as the leader key
  -- See `:help mapleader`
  --  NOTE: Must happen before plugins are loaded (otherwise wrong leader will be used)
  vim.g.mapleader = " "
  vim.g.maplocalleader = "\\"

  -- Sync clipboard between OS and Neovim.
  --  Schedule the setting after `UiEnter` because it can increase startup-time.
  --  Remove this option if you want your OS clipboard to remain independent.
  --  See `:help 'clipboard'`
  vim.schedule(function()
    vim.opt.clipboard = "unnamedplus"
  end)

  -- True color support
  vim.opt.termguicolors = true

  -- Number of spaces tabs count for
  vim.opt.tabstop = 2
  vim.opt.softtabstop = 0
  vim.opt.shiftwidth = 2
  vim.opt.laststatus = 3

  -- Show which line your cursor is on
  vim.opt.cursorline = true

  -- Make line numbers default
  vim.opt.number = true
end

return M
