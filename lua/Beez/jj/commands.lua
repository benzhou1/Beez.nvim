local M = {}

--- Runs jj st
---@param cb fun(err?: string, stdout?: string)
---@param opts? table
function M.st(cb, opts)
  opts = opts or {}
  local u = require("Beez.u")
  local cmd = { "jj", "st" }
  u.cmds.run(cmd, function(err, stdout)
    if err then
      vim.notify("Error running '" .. table.concat(cmd, " ") .. "': " .. err, vim.log.levels.WARN)
    end
    cb(err, stdout)
  end, opts)
end

--- Runs jj file show
---@param cb fun(err?: string, stdout?: string)
---@param opts? {r?: string, path?: string, ignore_err?: string[]}
function M.file_show(cb, opts)
  local u = require("Beez.u")
  opts = opts or {}

  local cmd = { "jj", "file", "show" }
  if opts.path ~= nil then
    table.insert(cmd, '"' .. opts.path .. '"')
  end
  if opts.r ~= nil then
    table.insert(cmd, "-r")
    table.insert(cmd, opts.r)
  end
  u.cmds.run(cmd, function(err, stdout)
    if err then
      vim.notify("Error running '" .. table.concat(cmd, " ") .. "': " .. err, vim.log.levels.WARN)
    end
    cb(err, stdout)
  end, opts)
end

return M
