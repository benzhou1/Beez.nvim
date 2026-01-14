local M = {}

--- Deck picker for zk notes by title
function M.notes(opts)
  opts = vim.tbl_deep_extend("force", opts or {}, { prompt = true })
  local source, identifier = require("beez.pickers.deck.zk.sources").notes({ prompt = true })
  return require("deck").start(source, identifier)
end

--- Deck picker for zk notes by body
function M.notes_body(opts)
  vim.ui.input({ prompt = "body: " }, function(res)
    if res == nil then
      return
    end
    opts = vim.tbl_deep_extend(
      "force",
      opts or {},
      { prompt = true, body = true, query = res, pattern = res }
    )
    local source, identifier = require("beez.pickers.deck.zk.sources").notes(opts)
    require("deck").start(source, identifier)
  end)
end

return M
