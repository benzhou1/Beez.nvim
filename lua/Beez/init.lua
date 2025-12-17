local config = require("Beez.config")
local M = {
  config = {},
}

--- Setup plugin
---@param opts Beez.config
function M.setup(opts)
  config.init(opts)
  M.pickers = require("Beez.pickers")
  M.u = require("Beez.u")
  M.ui = require("Beez.ui")
  M.cmds = require("Beez.cmds")
end

return M
