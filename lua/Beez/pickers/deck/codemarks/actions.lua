local M = { toggles = { global_codemarks = false } }

M.open_zed = require("Beez.pickers.deck.actions").open_zed

function M.toggle_global()
  return {
    name = "toggle_global",
    execute = function(ctx)
      M.toggles.global_codemarks = not M.toggles.global_codemarks
      ctx.execute()
    end,
  }
end

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

return M
