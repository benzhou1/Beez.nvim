local c = require("Beez.flotes.config")
local journal = require("Beez.flotes.journal")
local keymaps = require("Beez.flotes.keymaps")
local links = require("Beez.flotes.links")
local notes = require("Beez.flotes.notes")
local u = require("Beez.u")
local utils = require("Beez.flotes.utils")
local M = {
  states = {
    note = nil,
    ---@type Beez.ui.float?
    float = nil,
    zoomed = nil,
  },
  utils = utils,
  config = {},
}

--- Setup configurationk
---@param opts Beez.flotes.config
M.setup = function(opts)
  -- Initialize configuration
  local ok = c.init(opts)
  if not ok then
    return false
  end
  M.config = c.config

  ---@type Beez.ui.float.opts
  local float_opts = {
    win = c.config.float.float_opts,
    buffer = {
      del_bufs_on_close = c.config.float.del_bufs_on_close,
    },
    keymaps = {
      -- Keymaps per buffer
      buf_keymap_cb = function(bufnr)
        keymaps.bind_buf_keymaps(bufnr)
      end,
    },
    close_win_cb = c.config.float.close_win_cb,
  }

  -- Initialize float window
  M.states.float = require("Beez.ui.float").Float:new(float_opts)
end

---@class Beez.flotes.showopts
---@field note_name string? Name of the note to show
---@field note_path string? Path to the note to show

--- Show floating window with the note
---@param opts Beez.flotes.showopts?
function M.show(opts)
  opts = opts or {}

  local note_path = M.states.note
  if opts.note_name ~= nil then
    note_path = u.paths.Path:new(c.config.notes_dir):joinpath(opts.note_name).filename
  end
  if opts.note_path ~= nil then
    note_path = opts.note_path
  end

  -- Save currently opened note
  if note_path ~= nil then
    M.states.note = note_path
  end
  if c.config.open_in_float then
    M.states.float:show(note_path)
  else
    vim.cmd("edit " .. note_path)
    vim.schedule(function()
      keymaps.bind_buf_keymaps(vim.api.nvim_get_current_buf())
    end)
  end

  -- If zoomed, apply to float
  if M.states.zoom then
    M.states.float:zoom()
  end
end

--- Hide the floating window without closing it
function M.hide()
  if M.states.float ~= nil then
    M.states.float:hide()
  end
end

--- Close the floating window
function M.close()
  if M.states.float ~= nil then
    M.states.float:close()
  end
end

--- Toggles the floating window depending on quit_action
---@param opts Beez.flotes.showopts?
function M.toggle(opts)
  opts = opts or {}
  if M.states.float ~= nil then
    if M.states.float:is_showing() then
      if c.config.float.quit_action == "close" then
        return M.close()
      elseif c.config.float.quit_action == "hide" then
        return M.hide()
      end
    end
  end
  M.show(opts)
end

--- Toggles the focus between floating window
function M.toggle_focus()
  if M.states.float ~= nil then
    if M.states.float:is_showing() and M.states.float:is_focused() then
      M.states.float:toggle_hidden()
    else
      M.show()
    end
  else
    M.show()
  end
end

--- Focus on the floating window
function M.focus()
  if c.config.open_in_float then
    M.states.float:focus()
  end
end

--- Zoom the floating window
function M.zoom()
  M.states.zoom = true
  if M.states.float ~= nil then
    M.states.float:zoom()
  end
end

--- Unzoom the floating window
function M.unzoom()
  M.states.zoom = false
  if M.states.float ~= nil then
    M.states.float:unzoom()
  end
end

--- Toggle zoom
function M.toggle_zoom()
  if M.states.zoom then
    M.unzoom()
  else
    M.zoom()
  end
end

--- Whether the floating window is open
---@return boolean
function M.is_open()
  if M.states.float ~= nil then
    return M.states.float:is_showing()
  end
  return false
end

--- Creates a new note and shows it
---@param title string Title of the note
---@param opts {show: boolean?}
---@return string Path to the created note
function M.new_note(title, opts)
  opts = opts or {}
  local path = notes.create({ title = title })
  if opts.show ~= false then
    M.show({ note_path = path })
  end
  return path
end

---@class Beez.flotes.journalfindopts
---@field desc "today"|"yesterday"|"tomorrow"? Description of the journal to open
---@field direction "next"|"prev"? Get previous or next journal relative to current note
---@class Beez.flotes.journalopts
---@field create boolean? Create a new journal note if it doesnt exist

--- Opens or creates a journal note
---@param opts Beez.flotes.journalopts | Beez.flotes.journalfindopts?
function M.journal(opts)
  opts = opts or { desc = "today" }
  local find_opts = opts
  ---@cast find_opts Beez.flotes.journalfindopts
  local journal_ts = journal.find_journal(find_opts)
  local journal_name = tostring(journal_ts) .. ".md"
  local journal_path = u.paths.Path:new(c.config.journal_dir):joinpath(journal_name)

  if not journal_path:exists() then
    if not opts.create then
      return
    end
    local title = "Journal: " .. utils.dates.to_human_friendly(journal_ts)
    notes.create({ name = journal_name, title = tostring(title), dir = c.config.journal_dir })
    M.show({ note_path = journal_path.filename })
  else
    M.show({ note_path = journal_path.filename })
  end
end

---@class Beez.flotes.newnotetemplateopts
---@field picker_opts snacks.picker.Config? Options for the template picker
---@field template_opts Beez.flotes.templates.opts? Options for the template creation

--- Create a new note with template
---@param template_name string? Name of the template, empty to show picker
---@param opts? Beez.flotes.newnotetemplateopts Options for the picker or template creation
function M.new_note_from_template(template_name, opts)
  opts = opts or {}
  if template_name == nil then
    local picker_opts = vim.tbl_deep_extend("keep", opts.picker_opts or {}, c.config.pickers.templates)
    return pickers.templates.finder(picker_opts)
  end

  local template_opts = vim.tbl_deep_extend("keep", opts.template_opts or {}, {
    template = template_name,
  })
  ---@diagnostic disable-next-line: param-type-mismatch
  require("Beez.flotes.notes").create_template(template_opts)
end

--- Search for notes by name picker
---@param opts? table Options for the picker
function M.find_picker(opts)
  local def_type = "deck"
  local ok, _ = pcall(require, "deck")
  if not ok then
    def_type = "snacks"
  end

  opts = vim.tbl_deep_extend("keep", opts or {}, { type = def_type })
  require("Beez.pickers").pick("notes.find", opts)
end

--- Grep contents of notes picker
---@param opts? table Options for the picker
function M.grep_picker(opts)
  opts = vim.tbl_deep_extend("keep", opts or {}, { type = "deck" })
  require("Beez.pickers").pick("notes.grep", opts)
end

--- Find templates for notes picker
---@param opts? table
function M.templates_picker(opts)
  local def_type = "deck"
  local ok, _ = pcall(require, "deck")
  if not ok then
    def_type = "snacks"
  end

  opts = vim.tbl_deep_extend("keep", opts or {}, { type = def_type })
  require("Beez.pickers").pick("notes.find_templates", opts)
end

--- Show picker for backlinks to the current note
---@param opts? table
function M.backlinks_picker(opts)
  opts = opts or {}
  require("Beez.pickers").pick("notes.backlinks", opts)
end

--- Follows the markdown link under the cursor
function M.follow_link()
  links.follow_link()
end

--- Show picker to insert a link to a note at cursor position
---@param opts? table
function M.insert_link_picker(opts)
  require("Beez.pickers").snacks.flotes.insert_link(opts)
end

--- Show picker to replace visual selection with a link to a note
---@param opts? table
function M.replace_with_link_picker(opts)
  require("Beez.pickers").snacks.flotes.replace_with_link(opts)
end

return M
