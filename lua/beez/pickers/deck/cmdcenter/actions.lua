local u = require("beez.u")
local M = {}

--- Deck action to run the current command
---@param opts? table
---@return table[]
function M.run_cmd(opts)
  opts = opts or {}
  local name = "cmdcenter.run_cmd"
  return {
    require("deck").alias_action("default", name),
    {
      name = name,
      execute = function(ctx)
        local item = ctx.get_action_items()[1]
        local cc = require("beez.cmdcenter")
        cc.run(item.data.cmd)
        ctx.hide()
      end,
    },
  }
end

--- Deck action to move cursor to the specified header column
---@param opts? table
---@return table[]
function M.move_to_header(opts)
  opts = opts or {}
  local name = "cmdcenter.db.move_to_header"
  return {
    require("deck").alias_action("default", name),
    {
      name = name,
      execute = function(ctx)
        local item = ctx.get_action_items()[1]
        local cc = require("beez.cmdcenter")

        -- Focuses output window
        ctx.hide()
        u.async.delayed({
          delay = 100,
          cb = function()
            cc.op.focus_or_open()
            vim.schedule(function()
              cc.db.move_to_header(item.data.header)
            end)
          end,
        })
      end,
    },
  }
end

return M
