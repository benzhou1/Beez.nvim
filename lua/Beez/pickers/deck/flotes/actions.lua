local M = {}

--- Open note in flotes window
M.open_note = {
  name = "open_note",
  execute = function(ctx)
    local f = require("Beez.flotes")
    local item = ctx.get_action_items()[1]
    ctx:hide()
    vim.schedule(function()
      f.show({ note_path = item.data.filename })
      vim.schedule(function()
        if item.data.lnum then
          vim.fn.cursor(item.data.lnum, item.data.col)
        end
      end)
    end)
  end,
}

--- Create a new note with title
M.new_note = {
  name = "new_note",
  execute = function(ctx)
    local f = require("Beez.flotes")
    local title = ctx.get_query()
    ctx:hide()
    f.new_note(title, {})
  end,
}

--- Delete note
M.delete_note = {
  name = "delete_note",
  execute = function(ctx)
    local Path = require("plenary.path")
    for _, item in ipairs(ctx.get_action_items()) do
      local path = Path:new(item.data.filename)
      local choice = vim.fn.confirm("Are you sure you want to delete this note?", "&Yes\n&No")
      if choice == 1 then
        path:rm()
        vim.notify("Deleted note: " .. path.filename, "info")
        ctx:execute()
      end
    end
  end,
}

--- Create note from template
M.new_note_from_template = {
  name = "new_note_from_template",
  execute = function(ctx)
    local item = ctx.get_action_items()[1]
    ctx:hide()
    vim.schedule(function()
      require("Beez.flotes").new_note_from_template(item.data.name)
    end)
  end,
}

return M
