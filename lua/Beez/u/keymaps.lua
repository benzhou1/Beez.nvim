local M = {}

--- Set keymaps like lazy keys spec
---@param opts? {pick: string[]}
---@param keymaps table
function M.set(keymaps, opts)
  local u = require("Beez.u")
  opts = opts or {}
  for _, km in ipairs(keymaps) do
    local key = km[1]
    local action = km[2]
    local mode = km.mode or "n"

    local valid = true
    if opts.pick ~= nil and not u.tables.contains(opts.pick, key:lower()) then
      valid = false
    end
    if valid then
      if action == false then
        vim.keymap.del(mode, key)
      else
        vim.keymap.set(mode, key, action, {
          desc = km.desc,
          nowait = km.nowait,
          expr = km.expr,
          remap = km.remap,
          buffer = km.buffer,
        })
      end
    end
  end
end

--- Unset keymaps like lazy keys spec
---@param keymaps table
function M.unset(keymaps)
  for _, km in ipairs(keymaps) do
    local key = km[1]
    local mode = km.mode or "n"
    local ok, error = pcall(vim.keymap.del, mode, key, {
      buffer = km.buffer,
    })
  end
end

return M
