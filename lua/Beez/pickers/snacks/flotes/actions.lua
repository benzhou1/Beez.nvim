local M = {}

--- Create a new note and insert a link to it at the cursor position.
function M.create_link(picker)
  local f = require("Beez.flotes")
  local links = require("Beez.flotes.links")
  local note_path = M.create(picker, { show = false })
  f.focus()
  links.add_link_at_cursor(note_path)
end

--- Replace the selected text with a link to a new note.
function M.replace_link(line)
  return function(picker)
    local f = require("Beez.flotes")
    local links = require("Beez.flotes.links")
    local note_path = M.create(picker, { show = false })
    f.focus()
    links.replace_with_link(line, s, e, note_path)
  end
end

--- Confirm the selected note and open it in a new buffer.
function M.confirm(picker)
  local f = require("Beez.flotes")
  picker:close()
  local item = picker:current()
  if not item then
    return
  end
  f.show({ note_path = item.file })
end

--- Confirm the selected note and open it in a new buffer.
function M.create(picker, opts)
  local f = require("Beez.flotes")
  opts = opts or {}
  picker:close()
  local filter = picker.input.filter:clone({ trim = true })
  local title = filter.search
  return f.new_note(title, opts)
end

--- Delete the selected note
function M.delete(picker)
  local u = require("Beez.u")
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
function M.swtich_to_list(picker)
  require("snacks.picker.actions").cycle_win(picker)
  require("snacks.picker.actions").cycle_win(picker)
end

--- Creates a new note from a template
function M.create_from_template(picker)
  local item = picker:selected({ fallback = true })[1]
  if item == nil then
    return
  end
  picker:close()
  require("flotes.notes").create_template({ template = item.text })
end

--- Make sure to focus back the float after closing the picker
function M.add_link_finder_close(picker)
  local f = require("Beez.flotes")
  picker:close()
  ---@diagnostic disable-next-line: undefined-field
  if f.config.open_in_float then
    f.states.float:focus()
  end
end

return M
