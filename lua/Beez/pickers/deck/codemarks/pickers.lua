local M = {}

--- Deck for showing codemarks global marks
---@param opts table
function M.global_marks(opts)
  local source, specifier = require("Beez.pickers.deck.codemarks.sources").global_marks(opts)
  require("deck").start(source, specifier)
end

--- Deck for shwoing codemarks marks
---@param opts table
function M.marks(opts)
  local source, specifier = require("Beez.pickers.deck.codemarks.sources").marks(opts)
  require("deck").start(source, specifier)
end

--- Deck for showing codemark stacks
---@param opts table
function M.stacks(opts)
  local source, specifier = require("Beez.pickers.deck.codemarks.sources").stacks(opts)
  require("deck").start(source, specifier)
end

return M
