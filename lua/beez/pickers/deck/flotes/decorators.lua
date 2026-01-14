local M = {}

--- Deck decorator to aligns tass to the right and highlight
---@param opts? table
---@return deck.Decorator
function M.hash_tags(opts)
  opts = opts or {}
  return {
    name = "decorate_tags",
    resolve = function(_, item)
      return item.data.tags
    end,
    decorate = function(_, item)
      local virt_texts = {}
      for tag, _ in pairs(item.data.tags) do
        if not tag:startswith("task:") then
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
