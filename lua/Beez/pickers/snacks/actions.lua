local u = require("Beez.u")
local M = {}

--- Confirm the selected note and open it in a new buffer.
function M.note_confirm(picker)
  local f = require("Beez.flotes")
  picker:close()
  local item = picker:current()
  if not item then
    return
  end
  f.show({ note_path = item.file })
end

--- Confirm the selected note and open it in a new buffer.
function M.note_create(picker, opts)
  local f = require("Beez.flotes")
  opts = opts or {}
  picker:close()
  local filter = picker.input.filter:clone({ trim = true })
  local title = filter.search
  return f.new_note(title, opts)
end

--- Delete the selected note
function M.note_delete(picker)
  local item = picker:current()
  if not item then
    return
  end

  local path = u.paths.Path:new(item.file)
  local choice = vim.fn.confirm("Are you sure you want to delete this note?", "&Yes\n&No")
  if choice == 1 then
    path:rm()
    vim.notify("Deleted note: " .. item.file, "info")
    picker:close()
    vim.schedule(function()
      picker:resume()
    end)
  end
end

--- Switch to the list view in snacks picker
function M.note_switch_to_list(picker)
  require("snacks.picker.actions").cycle_win(picker)
  require("snacks.picker.actions").cycle_win(picker)
end

--- Creates a new note from a template
function M.note_template_create(picker)
  local item = picker:selected({ fallback = true })[1]
  if item == nil then
    return
  end
  picker:close()
  require("flotes.notes").create_template({ template = item.text })
end

return M
