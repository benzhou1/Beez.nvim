local M = {
  toggles = { done_task = false },
}

--- Open note in flotes window
---@param opts? table
---@return deck.Action[]
function M.open_note(opts)
  opts = opts or {}
  return {
    require("deck").alias_action("default", "open_note"),
    {
      name = "open_note",
      execute = function(ctx)
        local item = ctx.get_action_items()[1]
        local f = require("Beez.flotes")
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
    },
  }
end

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

--- Deck action to toggle showing done tasks or not
---@param opts? table
---@return deck.Action[]
function M.toggle_done_task(opts)
  opts = opts or {}
  return {
    require("deck").alias_action("toggle1", "toggle_done_task"),
    {
      name = "toggle_done_task",
      execute = function(ctx)
        M.toggles.done_task = not M.toggles.done_task
        if M.toggles.done_task then
          vim.notify("Showing done tasks...", vim.log.levels.INFO)
        else
          vim.notify("Showing only open tasks...", vim.log.levels.INFO)
        end
        ctx.execute()
      end,
    },
  }
end

return M
