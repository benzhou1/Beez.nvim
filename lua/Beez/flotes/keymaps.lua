local c = require("Beez.flotes.config")
local journal = require("Beez.flotes.journal")
local links = require("Beez.flotes.links")
local u = require("Beez.u")
local M = {}

--- Bind default keymaps to notes
---@param bufnr integer
function M.bind_note_keymaps(bufnr)
  local f = require("Beez.flotes")
  local set_spec = {}

  -- Hide keymap
  if c.config.float.quit_action == "hide" then
    table.insert(set_spec, {
      "q",
      f.hide,
      noremap = true,
      buffer = bufnr,
      desc = "Hide flotes",
    })
  -- Close keymap
  else
    table.insert(set_spec, {
      "q",
      f.close,
      noremap = true,
      buffer = bufnr,
      desc = "Close flotes",
    })
  end

  -- Insert link to note keymap
  if c.config.keymaps.add_note_link ~= false then
    table.insert(set_spec, {
      c.config.keymaps.add_note_link,
      mode = { "i" },
      links.add_note_link,
      noremap = true,
      buffer = bufnr,
      desc = "Add note link",
    })
  end

  -- Convert visual selection to link keymap
  if c.config.keymaps.add_note_link_visual ~= false then
    table.insert(set_spec, {
      c.config.keymaps.add_note_link_visual,
      mode = { "x" },
      links.replace_with_link,
      noremap = true,
      buffer = bufnr,
      desc = "Replace with note link",
    })
  end

  u.keymaps.set(set_spec)

  -- Custom keymaps for note files only
  if c.config.keymaps.note_keys then
    c.config.keymaps.note_keys(bufnr)
  end

  -- Journal keymaps, if current buffer is a journal
  local filepath = vim.api.nvim_buf_get_name(bufnr)
  if journal.is_journal(filepath) then
    M.bind_journal_keymaps(bufnr)
  end
end

--- Bind keymaps to current journal buffer
---@param bufnr integer
function M.bind_journal_keymaps(bufnr)
  local set_spec = {}

  -- Previous journal keymap
  if c.config.keymaps.prev_journal ~= false then
    table.insert(set_spec, M.journal_keymaps.prev_journal(c.config.keymaps.prev_journal, bufnr))
  end

  -- Next journal keymap
  if c.config.keymaps.next_journal ~= false then
    table.insert(set_spec, M.journal_keymaps.next_journal(c.config.keymaps.next_journal, bufnr))
  end

  u.keymaps.set(set_spec)

  -- Custom keymaps for journal files only
  if c.config.keymaps.journal_keys then
    c.config.keymaps.journal_keys(bufnr)
  end
end

return M
