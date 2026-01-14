local M = {}

---@class Beez.u.cmds.RunOpts
---@field ignore_err? string[]
---@field env? table<string, string>
---@field cwd? string
---@field detach? boolean
---@field wait? boolean
---@field verbose? boolean

--- Runs a command. Async if cb is provided.
---@param cmd string[]
---@param cb? fun(err: string|nil, stdout?: string, stderr?: string)
---@param opts? Beez.u.cmds.RunOpts
function M.run(cmd, cb, opts)
  opts = opts or {}
  local system_opts = {
    text = true,
    env = opts.env,
    cwd = opts.cwd,
    detach = opts.detach,
  }
  if cb == nil then
    local sys = vim.system(cmd, system_opts)
    if opts.wait ~= false then
      return sys:wait()
    end
    return sys
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
    elseif opts.verbose == true then
      vim.notify(vim.inspect(cmd) .. ":\n" .. obj.stdout .. obj.stderr, vim.log.levels.INFO)
    end
    cb(nil, obj.stdout, obj.stderr)
  end)
end

return M
