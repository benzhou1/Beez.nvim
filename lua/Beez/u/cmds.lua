local M = {}

--- Runs a command. Async if cb is provided.
---@param cmd string[]
---@param cb? fun(err: string|nil, stdout: string|nil)
---@param opts? {ignore_err?: string[]}
function M.run(cmd, cb, opts)
  opts = opts or {}
  if cb == nil then
    return vim.system(cmd, { text = true }):wait()
  end

  vim.system(cmd, { text = true }, function(obj)
    if obj.code ~= 0 then
      if opts.ignore_err ~= nil then
        for _, ie in ipairs(opts.ignore_err) do
          if obj.stderr:contains(ie) then
            return cb(nil, "")
          end
        end
      end
      vim.notify(obj.stderr, vim.log.levels.WARN)
      return cb(obj.stderr, nil)
    end
    cb(nil, obj.stdout)
  end)
end

return M
