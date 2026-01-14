local c = require("beez.flotes.config")
local journal = require("beez.flotes.journal")
local M = {}

--- Bind keymap hooks to buffer
---@param bufnr integer
function M.bind_buf_keymaps(bufnr)
  if c.config.keymaps.note_keys then
    c.config.keymaps.note_keys(bufnr)
  end
  -- Keymaps for journal files only
  local filepath = vim.api.nvim_buf_get_name(bufnr)
  if c.config.keymaps.journal_keys and journal.is_journal(filepath) then
    c.config.keymaps.journal_keys(bufnr)
  end
end

return M
