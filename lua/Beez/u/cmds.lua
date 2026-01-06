local M = {}

--- Runs a command. Async if cb is provided.
---@param cmd string[]
---@param cb? fun(err: string|nil, stdout: string|nil)
---@param opts? {ignore_err?: string[], env?: table<string, string>, cwd?: string, detach?: boolean}
function M.run(cmd, cb, opts)
  opts = opts or {}
  local system_opts = {
    text = true,
    env = opts.env,
    cwd = opts.cwd,
    detach = opts.detach,
  }
  if cb == nil then
    return vim.system(cmd, system_opts):wait()
  end

  vim.system(cmd, system_opts, function(obj)
    if obj.code ~= 0 then
      if opts.ignore_err ~= nil then
        for _, ie in ipairs(opts.ignore_err) do
          if obj.stderr:contains(ie) then
            return cb(nil, "")
          end
        end
      end
      vim.schedule(function()
        vim.notify(
          "Error running '" .. table.concat(cmd, " ") .. "': " .. obj.stderr,
          vim.log.levels.WARN
        )
      end)
      return cb(obj.stderr, nil)
    end
    cb(nil, obj.stdout)
  end)
end

return M
