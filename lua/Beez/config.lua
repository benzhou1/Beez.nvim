local M = {}

---@class Beez.config
---@field flotes Beez.flotes.config? Configuration for the flotes module

---@type Beez.config
local def_config = {
  flotes = {
    enabled = false,
    notes_dir = nil,
    journal_dir = nil,
    open_in_float = true,
    keymaps = {
      prev_journal = false,
      next_journal = false,
      add_note_link = false,
      add_note_link_visual = false,
      today_journal = false,
      notes_picker = false,
      notes_grep_picker = false,
      templates_picker = false,
      journal_keys = nil,
      note_keys = nil,
    },
    float = {
      quit_action = "close",
      float_opts = {
        x = 0.25,
        y = 0.25,
        w = 0.5,
        h = 0.5,
        border = "rounded",
        del_bufs_on_close = true,
      },
    },
    pickers = {
      notes = { type = "deck" },
      insert_link = { type = "snacks" },
      templates = { type = "snacks" },
    },
    templates = {
      expand = function(...)
        vim.snippet.expand(...)
      end,
      templates = {},
    },
  },
}

--- Initializes configuration with default
---@param opts Beez.config
function M.init(opts)
  M.config = vim.tbl_deep_extend("force", {}, def_config, opts or {})
end

return M
