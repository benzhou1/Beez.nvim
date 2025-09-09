local sources = require("Beez.pickers.deck.codestacks.sources")
local M = {}

--- Deck picker for codestacks stacks
---@param opts? table
function M.stacks(opts)
  local source, specifier = sources.stacks(opts)
  require("deck").start(source, specifier)
end

--- Deck picker for codestacks global marks
---@param opts? table
function M.global_marks(opts)
  local source, specifier = sources.global_marks(opts)
  require("deck").start(source, specifier)
end

return M
