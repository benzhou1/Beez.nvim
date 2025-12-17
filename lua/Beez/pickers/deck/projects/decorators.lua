local M = {}

--- Deck decorator to display the root path at the end of the line
---@return deck.Decorator
function M.root_path()
  return {
    name = "decorators.projects.root_path",
    resolve = function(_, item)
      return item.data.root
    end,
    decorate = function(_, item)
      local dec = {
        {
          col = 0,
          virt_text = { { item.data.root, "Comment" } },
          virt_text_pos = "eol",
          hl_mode = "combine",
          ephemeral = true,
        },
      }
      return dec
    end,
  }
end

return M
