local M = {}

--- Deck decorator to aligns tags to the right and highlight
---@param opts? table
---@return deck.Decorator
function M.hash_tags(opts)
  opts = opts or {}
  return {
    name = "decorate_tags",
    resolve = function(_, item)
      return item.data.cmd.tags
    end,
    decorate = function(_, item)
      local virt_texts = {}
      for tag, _ in pairs(item.data.cmd.tags) do
        local hl = "Title"
        if tag == "db" then
          hl = "Search"
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
