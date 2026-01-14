local M = {}

--- Use aerospace to check whether a specific app with a specific title is focused
---@param opts {app?: string, title?: string, cb: fun()}
function M.until_focused(opts)
  opts = opts or {}
  local u = require("Beez.u")
  local cmd = { "aerospace", "list-windows", "--focused" }
  local done = false

  u.async.periodic({
    delay = 300,
    interval = 300,
    timeout = 5000,
    cb = function(timer)
      local output = u.cmds.run(cmd)
      if output == nil or output.code ~= 0 then
        return
      end

      local parts = vim.split(output.stdout:gsub("\n", ""), " | ")
      local pid, app, title = parts[1], parts[2], parts[3]
      local found = true
      if opts.app ~= nil and opts.app ~= app then
        found = false
      end
      if opts.title ~= nil and opts.title ~= title then
        found = false
      end
      if found then
        pcall(function()
          timer:close()
        end)
        if not done then
          done = true
          opts.cb()
        end
      end
    end,
  })
end

return M
