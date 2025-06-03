local sources = require("Beez.pickers.deck.dbfp.sources")
local M = {}

--- Deck for dbfp connections
---@param opts table?
function M.connections(opts)
  local source, specifier = sources.connections(opts)
  require("deck").start(source, specifier)
end

--- Deck for dbfp queries
---@param opts table?
function M.queries(opts)
  opts = opts or {}
  local source, specifier = sources.queries(opts)
  require("deck").start(source, specifier)
end

--- Deck for listing query files
---@param opts {connection?: string}?
function M.queryfiles(opts)
  opts = opts or {}
  local source, specifier = sources.queryfiles(opts)
  require("deck").start(source, specifier)
end

return M
