local M = {}

---@class Beez.u.async.periodicopts
---@field delay number
---@field timeout integer
---@field interval number
---@field cb function

--- Runs a function periodically
---@param opts Beez.u.async.periodicopts
function M.periodic(opts)
  local timer = vim.uv.new_timer()

  if timer ~= nil then
    ---@diagnostic disable-next-line: param-type-mismatch
    local start = os.time(os.date("!*t"))
    timer:start(
      opts.delay,
      opts.interval,
      vim.schedule_wrap(function()
        local status, error = pcall(opts.cb, timer)
        if not status then
          vim.notify("Failed periodic function: " .. vim.inspect(error), "error")
        end
        ---@diagnostic disable-next-line: param-type-mismatch
        if os.time(os.date("!*t")) - start > opts.timeout then
          pcall(function()
            timer:close()
          end)
        end
      end)
    )
  end
end

---@class Beez.u.async.delayedopts
---@field delay number
---@field cb function

--- Runs a function periodically
---@param opts Beez.u.async.delayedopts
function M.delayed(opts)
  local timer = vim.uv.new_timer()
  if timer ~= nil then
    timer:start(
      opts.delay,
      0,
      vim.schedule_wrap(function()
        local status, error = pcall(opts.cb, timer)
        if not status then
          vim.notify("Failed delayed function: " .. vim.inspect(error), "error")
        end
        pcall(function()
          timer:close()
        end)
      end)
    )
  end
end

return M
