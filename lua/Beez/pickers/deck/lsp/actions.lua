local M = {}

--- Deck action that will use overlook to peek at the item
---@return table
function M.peek()
  return {
    require("deck").alias_action("default", "overlook.peek"),
    {
      name = "overlook.peek",
      execute = function(ctx)
        local item = ctx.get_action_items()[1]

        local ok, overlook_ui = pcall(require, "overlook.ui")
        if not ok then
          vim.cmd("e " .. item.data.filename)
          return
        end

        ctx.hide()
        vim.schedule(function()
          overlook_ui.create_popup({
            target_bufnr = item.data.target_bufnr,
            lnum = item.data.lnum,
            col = item.data.col,
            title = item.data.filename,
          })
        end)
      end,
    },
  }
end

return M
