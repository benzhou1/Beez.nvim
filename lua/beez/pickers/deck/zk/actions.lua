local M = { open = {} }

M.open.name = "zk.open"
--- Deck action to open a zk note
---@return deck.Action
function M.open.action()
  local zk = require("beez.zk")
  return {
    require("deck").alias_action("default", M.open.name),
    {
      name = M.open.name,
      execute = function(ctx)
        local item = ctx.get_action_items()[1]
        ctx:hide()
        vim.schedule(function()
          zk.edit(item.data.path)
        end)
      end,
    },
  }
end

return M
