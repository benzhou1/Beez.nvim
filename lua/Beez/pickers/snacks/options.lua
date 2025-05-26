local pickers = require("Beez.pickers.snacks.pickers")
local M = {}

function M.smart()
  return {
    finder = pickers.smart,
    format = "file",
    matcher = {
      -- Dont sort when empty becaues we already sort it
      sort_empty = false,
      -- I prefer exact match for file names
      -- fuzzy = false,
      filename_bonus = true,
    },
    hidden = true,
    -- Because we concat all the items
    supports_live = false,
    win = {
      input = {
        keys = {
          ["dd"] = "bufdelete",
          ["<c-x>"] = { "bufdelete", mode = { "n", "i" } },
        },
      },
      list = { keys = { ["dd"] = "bufdelete" } },
    },
    layout = { preview = false },
  }
end

function M.dirs()
  return {
    finder = pickers.dirs,
    format = "file",
    confirm = function(picker)
      picker:close()
      local item = picker:current()
      if not item then
        return
      end
      local dir = item.file
      require("oil").open_float(dir)
    end,
    win = {
      preview = {
        minimal = true,
      },
    },
  }
end

return M
