local M = {}
M.neovide = require("Beez.cmds.neovide")
M.aerospace = require("Beez.cmds.aerospace")

--- Runs a command in the background
---@param cmd string[]
function M.run_job(cmd, opts)
  opts = opts or {}
  local cmd_str = table.concat(cmd, " ")
  vim.fn.jobstart(cmd_str, { detach = true, env = opts.env, cwd = opts.cwd })
end

return M
