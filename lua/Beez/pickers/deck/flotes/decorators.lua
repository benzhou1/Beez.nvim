local M = {}

--- Deck decorator to aligns tass to the right and highlight
---@param opts? table
---@return deck.Decorator
function M.hash_tags(opts)
  opts = opts or {}
  return {
    name = "decorate_tags",
    resolve = function(_, item)
      return item.data.tags and #item.data.tags > 0
    end,
    decorate = function(_, item)
      local virt_texts = {}
      for _, tag in ipairs(item.data.tags) do
        local hl = "Title"
        if tag == "p1" or tag == "bug" then
          hl = "DiagnosticError"
        elseif tag == "p2" then
          hl = "DiagnosticOk"
        elseif tag == "p3" then
          hl = "DiagnosticInfo"
        end
        table.insert(virt_texts, { (" #%s"):format(tag), hl })
      end
      local dec = {
        {
          col = 0,
          virt_text = virt_texts,
          virt_text_pos = "right_align",
          hl_mode = "combine",
        },
      }
      return dec
    end,
  }
end

return M
