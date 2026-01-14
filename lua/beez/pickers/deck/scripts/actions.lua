local M = {}
local cmds = require("beez.cmds")

M.run_cmd_external = {}
--- Deck action to run a command in a neovide terminal window
---@param opts? table
---@return deck.Action[]
function M.run_cmd_external.action(opts)
  opts = opts or {}
  return {
    require("deck").alias_action("default", M.run_cmd_external.name),
    {
      name = M.run_cmd_external.name,
      execute = function(ctx)
        local item = ctx.get_action_items()[1]
        cmds.neovide.run_cmd(item.data.cmd)
        ctx:hide()
        if opts.quit then
          vim.schedule(function()
            vim.cmd("q")
          end)
        end
      end,
    },
  }
end
M.run_cmd_external.name = "scripts.run_cmd_external"

return M
