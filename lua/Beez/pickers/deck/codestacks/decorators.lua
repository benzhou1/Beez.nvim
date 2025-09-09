local M = {}

--- Deck decorator to aligns stack name when showing all global marks
---@param opts? table
---@return deck.Decorator
function M.stack_name(opts)
  opts = opts or {}
  return {
    name = "codestacks.stack_name",
    resolve = function(_, item)
      return item.data.stack
    end,
    decorate = function(_, item)
      local virt_texts = { { "#" .. item.data.stack, "Title" } }
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
