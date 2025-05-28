local config = require("Beez.config")
local M = {
  config = {},
}

--- Setup plugin
---@param opts Beez.config
function M.setup(opts)
  config.init(opts)
end

M.pickers = require("Beez.pickers")
M.u = require("Beez.u")
M.ui = require("Beez.ui")
M.flotes = require("Beez.flotes")
M.bufswitcher = require("Beez.bufswitcher")
M.scratches = require("Beez.scratches")
M.codemarks = require("Beez.codemarks")

return M
