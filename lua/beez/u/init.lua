local M = { ui = {} }

M.paths = require("beez.u.paths")
M.strs = require("beez.u.strings")
M.strings = M.strs
M.async = require("beez.u.async")
M.class = require("beez.u.class")
M.nvim = require("beez.u.nvim")
M.os = require("beez.u.os")
M.tables = require("beez.u.tables")
M.utf8 = require("beez.u.utf8")
M.json = require("beez.u.dkjson")
M.root = require("beez.u.root")
M.lazy = require("beez.u.lazy")
M.keymaps = require("beez.u.keymaps")
M.snip = require("beez.u.snippets")
M.deck = require("beez.u.deck")
M.cmds = require("beez.u.cmds")

--- Setup u
---@param opts table?
function M.setup(opts)
  M.paths.Path = require("plenary.path")
end
return M
