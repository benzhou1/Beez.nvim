local M = { toggles = { global_codemarks = false } }

M.open_zed = require("Beez.pickers.deck.actions").open_zed

---@return deck.Action
function M.toggle_global()
  return {
    name = "toggle_global",
    ---@param ctx deck.Context
    execute = function(ctx)
      M.toggles.global_codemarks = not M.toggles.global_codemarks
      if M.toggles.global_codemarks then
        vim.notify("Showing all codemarks globally", vim.log.levels.INFO)
      else
        vim.notify("Showing codemarks for current project only", vim.log.levels.INFO)
      end
      ctx.execute()
    end,
  }
end

---@return deck.Action
function M.delete()
  return {
    name = "delete_mark",
    execute = function(ctx)
      local marks = require("Beez.codemarks").marks
      for _, item in ipairs(ctx.get_action_items()) do
        marks:del(item.data.data)
      end
      ctx.execute()
    end,
  }
end

---@return deck.Action
function M.open()
  local open_action = require("deck.builtin.action").open
  return {
    name = "open_codemarks",
    resolve = open_action.resolve,
    ---@param ctx deck.Context
    execute = function(ctx)
      local item = ctx.get_action_items()[1]
      open_action.execute(ctx)
      vim.schedule(function()
        require("Beez.codemarks").check_for_outdated_marks(item.data.filename, item.data.lnum)
      end)
    end,
  }
end

return M
