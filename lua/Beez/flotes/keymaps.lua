local c = require("Beez.flotes.config")
local f = require("Beez.flotes")
local journal = require("Beez.flotes.journal")
local links = require("Beez.flotes.links")
local u = require("Beez.u")

local M = {
  def_keymaps = {
    quit = function(buf)
      return {
        "q",
        f.hide,
        noremap = true,
        buffer = buf,
        desc = "Close flotes",
      }
    end,
    hide = function(buf)
      return {
        "q",
        f.hide,
        noremap = true,
        buffer = buf,
        desc = "Hide flotes",
      }
    end,
    add_note_link = function(lhs, buf)
      return {
        lhs,
        mode = { "i" },
        links.add_note_link,
        noremap = true,
        buffer = buf,
        desc = "Add note link",
      }
    end,
    add_note_link_visual = function(lhs, buf)
      return {
        lhs,
        mode = { "x" },
        links.replace_with_link,
        noremap = true,
        buffer = buf,
        desc = "Replace with note link",
      }
    end,
  },
  journal_keymaps = {
    prev_journal = function(lhs, buf)
      return {
        lhs,
        function()
          f.journal({ direction = "prev" })
        end,
        noremap = true,
        buffer = buf,
        desc = "Previous journal",
      }
    end,
    next_journal = function(lhs, buf)
      return {
        lhs,
        function()
          f.journal({ direction = "next" })
        end,
        noremp = true,
        buffer = buf,
        desc = "Next journal",
      }
    end,
  },
}

--- Bind default keymaps to notes
---@param bufnr integer
function M.bind_note_keymaps(bufnr)
  local set_spec = {}

  -- Hide keymap
  if c.config.float.quit_action == "hide" then
    table.insert(set_spec, M.def_keymaps.hide(bufnr))
  -- Close keymap
  else
    table.insert(set_spec, M.def_keymaps.quit(bufnr))
  end

  -- Insert link to note keymap
  if c.config.keymaps.add_note_link ~= false then
    table.insert(set_spec, M.def_keymaps.add_note_link(bufnr))
  end

  -- Convert visual selection to link keymap
  if c.config.keymaps.add_note_link_visual ~= false then
    table.insert(set_spec, M.def_keymaps.add_note_link_visual(bufnr))
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
