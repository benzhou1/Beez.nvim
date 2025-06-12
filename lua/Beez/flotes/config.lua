local u = require("Beez.u")
local M = {
  ---@type Beez.flotes.config
  config = {}
}

---@class Beez.flotes.float.config
---@field quit_action ("close" | "hide")? Action to take when the float is closed. Defaults to "close"
---@field del_bufs_on_close boolean? Whether to delete buffers on close. Defaults to true
---@field close_win_cb fun(win: integer)? Callback to run when the floating window is closed
---@field float_opts Beez.ui.float.win.opts Options for the floating window

---@class Beez.flotes.keymaps.config
---@field journal_keys fun(bufnr: integer)? Callback to create custom keymaps for journal files
---@field note_keys fun(bufnr: integer)? Callback to create custom keymaps for note files

---@class Beez.flotes.templates.template.config
---@field template string Template for creating notes. Supports snippet syntax.

---@class Beez.flotes.templates.config
---@field templates table<string, Beez.flotes.templates.template.config> Templates for creating notes
---@field expand fun(...) Function to expand a template

---@class Beez.flotes.config
---@field enabled boolean? Enable the flotes module. Defaults to false.
---@field notes_dir string? Absolute path to the notes directory
---@field journal_dir string? Absolute path to the journal directory. Defaults to {notes_dir}/journal.
---@field open_in_float boolean? Open notes in a floating window otherwise open in current window. Defaults to true.
---@field float Beez.flotes.float.config? Configuration for the floating window
---@field keymaps Beez.flotes.keymaps.config? Keymaps for the notes and journal files
---@field templates Beez.flotes.templates.config? Templates for creating notes

---@type Beez.flotes.config
M.def_config = {
  enabled = false,
  notes_dir = nil,
  journal_dir = nil,
  open_in_float = true,
  keymaps = {
    journal_keys = nil,
    note_keys = nil,
  },
  float = {
    quit_action = "close",
    del_bufs_on_close = true,
    float_opts = {
      x = 0.25,
      y = 0.25,
      w = 0.5,
      h = 0.5,
      border = "rounded",
    },
  },
  templates = {
    expand = function(...)
      vim.snippet.expand(...)
    end,
    templates = {},
  },
}

--- Intialize flote configuration
---@param opts Beez.flotes.config
---@return boolean
function M.init(opts)
  M.config = vim.tbl_deep_extend("keep", {}, opts or {}, M.def_config)

  -- Notes dir is required
  if M.config.notes_dir == nil then
    vim.notify("flotes: notes_dir is not set", vim.log.levels.ERROR)
    return false
  end
  -- Expand notes_dir to absolute path
  local notes_dir = vim.fn.expand(M.config.notes_dir)
  -- Make sure notes_dir exists
  if not u.paths.Path:new(notes_dir):exists() then
    vim.notify("flotes: notes_dir=" .. notes_dir .. " does not exist", vim.log.levels.ERROR)
    return false
  end
  M.config.notes_dir = notes_dir

  -- Journals dir defaults to notes_dir/journal
  if M.config.journal_dir == nil then
    M.config.journal_dir = u.paths.Path:new(opts.notes_dir):joinpath("journal").filename
  end
  -- Expand journal_dir to absolute path
  M.config.journal_dir = vim.fn.expand(M.config.journal_dir)
  local journal_dir = u.paths.Path:new(M.config.journal_dir)
  -- Make sure journal_dir exists, otherwise create it
  if not journal_dir:exists() then
    journal_dir:mkdir()
  end

  -- Support percentage values for float_opts
  local float_opts = vim.tbl_deep_extend("keep", {}, opts, M.config.float.float_opts)
  if float_opts.x < 1 then
    M.config.float.float_opts.x = math.floor(vim.o.columns * float_opts.x)
  end
  if float_opts.y < 1 then
    M.config.float.float_opts.y = math.floor(vim.o.lines * float_opts.y)
  end
  if float_opts.w < 1 then
    M.config.float.float_opts.w = math.floor(vim.o.columns * float_opts.w)
  end
  if float_opts.h < 1 then
    M.config.float.float_opts.h = math.floor(vim.o.lines * float_opts.h)
  end
  return true
end

return M
