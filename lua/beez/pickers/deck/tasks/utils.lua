local tasks = require("beez.flotes.tasks")
local M = {}

--- Gets the current task on the cursor
---@param ctx deck.Context
---@return Beez.flotes.task, deck.Item
function M.get_current_task(ctx)
  local tl = tasks.get_tasks()
  local item = ctx.get_cursor_item()
  assert(item ~= nil, "Item not found")
  local task = tl:get(item.data.id)
  assert(task ~= nil, "Task not found:" .. item.data.id)
  return task, item
end

return M
