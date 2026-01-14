local M = {}

--- Deck picker for zk notes by title
function M.notes()
  local source, identifier = require("Beez.pickers.deck.zk.sources").notes({ prompt = true })
  return require("deck").start(source, identifier)
end

return M
