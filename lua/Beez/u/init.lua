local M = { ui = {} }

M.paths = require("Beez.u.paths")
M.strs = require("Beez.u.strings")
M.async = require("Beez.u.async")
M.class = require("Beez.u.class")
M.nvim = require("Beez.u.nvim")
M.os = require("Beez.u.os")
M.tables = require("Beez.u.tables")
M.utf8 = require("Beez.u.utf8")
M.json = require("Beez.u.dkjson")
M.root = require("Beez.u.root")
M.lazy = require("Beez.u.lazy")
M.keymaps = require("Beez.u.keymaps")

M.apps = require("Beez.u.apps")

--- Setup u
---@param opts table?
function M.setup(opts)
  M.paths.Path = require("plenary.path")
end
return M
