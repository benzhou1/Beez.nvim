local Buflist = require("Beez.bufswitcher.buflist")
local c = require("Beez.bufswitcher.config")
local u = require("Beez.u")

---@class Beez.bufswitcher
---@field config Beez.bufswitcher.config
---@field bl Beez.bufswitcher.buflist
local M = {
  config = {},
}

--- Setup keymaps and user nvim_create_user_command
---@param opts Beez.bufswitcher.config
function M.setup(opts)
  opts = vim.tbl_deep_extend("keep", {}, opts or {})
  c.init(opts)
  M.config = c.config
  M.bl = Buflist:new()
end

--- Check to see if popup is open
---@return boolean
function M.is_open()
  return M.bl:is_open()
end

--- Close the popup
function M.close()
  M.bl:close()
end

--- Show the popup
---@param opts? {focus?: boolean}
function M.show(opts)
  M.bl:show(opts)
end

--- Update the buffer list
function M.update(opts)
  M.bl:update(opts)
end

return M
