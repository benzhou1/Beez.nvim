local M = {}
M.neovide = require("Beez.cmds.neovide")

--- Runs a command in the background
---@param cmd string[]
function M.run_job(cmd, opts)
  opts = opts or {}
  local cmd_str = table.concat(cmd, " ")
  vim.fn.jobstart(cmd_str, { detach = true, env = opts.env, cwd = opts.cwd })
end

--- Runs a command blocking
---@param cmd string[]
function M.run(cmd, opts)
  opts = opts or {}
  local cmd_str = table.concat(cmd, " ")
  vim.fn.system(cmd_str, { detach = true, env = opts.env })
end

return M
