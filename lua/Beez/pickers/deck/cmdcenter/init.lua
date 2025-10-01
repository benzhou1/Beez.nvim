local sources = require("Beez.pickers.deck.cmdcenter.sources")
local M = {}

--- Deck picker for list of cmds
---@param opts? table
function M.cmds(opts)
  opts = opts or {}
  local source, specifier = sources.cmds(opts)
  require("deck").start(source, specifier)
end

--- Deck picker for list of database headers
---@param opts? table
function M.db_headers(opts)
  opts = opts or {}
  local source, specifier = sources.db_headers(opts)
  require("deck").start(source, specifier)
end

return M
