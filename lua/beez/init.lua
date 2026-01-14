local config = require("beez.config")
local M = {
  config = {},
}

--- Setup plugin
---@param opts Beez.config
function M.setup(opts)
  config.init(opts)
  M.pickers = require("beez.pickers")
  M.u = require("beez.u")
  M.ui = require("beez.ui")
  M.cmds = require("beez.cmds")
end

return M
