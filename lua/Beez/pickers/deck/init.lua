local M = require("Beez.pickers.deck.pickers")

M.formatters = require("Beez.pickers.deck.formatters")
M.previewers = require("Beez.pickers.deck.previewers")
M.actions = require("Beez.pickers.deck.actions")
M.decorators = require("Beez.pickers.deck.decorators")
M.sources = require("Beez.pickers.deck.sources")
M.utils = require("Beez.pickers.deck.utils")
-- M.tasks = require("Beez.pickers.deck.tasks")
M.codemarks = require("Beez.pickers.deck.codemarks")
M.scratches = require("Beez.pickers.deck.scratches")
M.flotes = require("Beez.pickers.deck.flotes")
M.dbfp = require("Beez.pickers.deck.dbfp")
M.bufswitcher = require("Beez.pickers.deck.bufswitcher")
M.codestacks = require("Beez.pickers.deck.codestacks")
M.cmdcenter = require("Beez.pickers.deck.cmdcenter")
M.timber = require("Beez.pickers.deck.timber")
M.projects = require("Beez.pickers.deck.projects")
M.scripts = require("Beez.pickers.deck.scripts")

--- Deck picker for recent directories
---@param opts? table
---@return deck.Context
function M.recent_dirs(opts)
  local source, specifier = M.sources.dirs_recent(opts)
  local ctx = require("deck").start(source, specifier)
  return ctx
end

return M
