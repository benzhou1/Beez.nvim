local M = require("beez.pickers.deck.pickers")

M.formatters = require("beez.pickers.deck.formatters")
M.previewers = require("beez.pickers.deck.previewers")
M.actions = require("beez.pickers.deck.actions")
M.decorators = require("beez.pickers.deck.decorators")
M.sources = require("beez.pickers.deck.sources")
M.utils = require("beez.pickers.deck.utils")
-- M.tasks = require("beez.pickers.deck.tasks")
M.codemarks = require("beez.pickers.deck.codemarks")
M.scratches = require("beez.pickers.deck.scratches")
M.flotes = require("beez.pickers.deck.flotes")
M.dbfp = require("beez.pickers.deck.dbfp")
M.bufswitcher = require("beez.pickers.deck.bufswitcher")
M.codestacks = require("beez.pickers.deck.codestacks")
M.cmdcenter = require("beez.pickers.deck.cmdcenter")
M.timber = require("beez.pickers.deck.timber")
M.projects = require("beez.pickers.deck.projects")
M.scripts = require("beez.pickers.deck.scripts")

--- Deck picker for recent directories
---@param opts? table
---@return deck.Context
function M.recent_dirs(opts)
  local source, specifier = M.sources.dirs_recent(opts)
  local ctx = require("deck").start(source, specifier)
  return ctx
end

return M
