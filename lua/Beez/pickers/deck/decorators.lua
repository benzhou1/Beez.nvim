local u = require("Beez.u")
local M = {}

-- Just decorator for buffer flags without icons
M.buf_flags = {
  name = "custom.buf_flags",
  resolve = function(_, item)
    return item.data.filename
  end,
  decorate = function(_, item)
    local x = require("deck.x")
    local dec = {}
    local virtual_text = {}
    local buf = x.get_bufnr_from_filename(item.data.filename)
    if buf and vim.fn.isdirectory(item.data.filename) ~= 1 then
      local modified = vim.api.nvim_get_option_value("modified", { buf = buf })
      if modified then
        table.insert(virtual_text, { "[+]", "SpecialKey" })
      end
    end

    if buf and u.nvim.valid_buf(buf) then
      table.insert(virtual_text, { " " })
      table.insert(virtual_text, { ("#%s"):format(buf), "SnacksPickerTitle" })
    end

    if virtual_text ~= {} then
      table.insert(dec, {
        col = 0,
        virt_text = virtual_text,
        virt_text_pos = "eol",
        hl_mode = "combine",
        ephemeral = true,
      })
    end
    return dec
  end,
}

M.query = {
  name = "custom.query",
  resolve = function(_, item)
    return item.data.query ~= nil and item.data.query ~= ""
  end,
  decorate = function(_, item)
    local dec = {}
    local queries = vim.fn.split(item.data.query)

    for _, q in ipairs(queries) do
      local start_idx, end_idx = string.find(string.lower(item.display_text), string.lower(q))
      while start_idx ~= nil and end_idx ~= nil do
        table.insert(dec, {
          col = start_idx - 1,
          end_col = end_idx,
          hl_group = "Search",
          ephemeral = true,
          priority = 9999,
        })
        start_idx, end_idx = string.find(string.lower(item.display_text), string.lower(q), end_idx)
      end
    end
    return dec
  end,
}

M.source = {
  name = "custom.source",
  resolve = function(_, item)
    return item.data.source ~= nil and item.data.source ~= ""
  end,
  decorate = function(_, item)
    local dec = {}
    local virtual_text = {}
    table.insert(virtual_text, { " " })
    table.insert(virtual_text, { item.data.source, "Comment" })

    if virtual_text ~= {} then
      table.insert(dec, {
        col = 0,
        virt_text = virtual_text,
        virt_text_pos = "right_align",
        hl_mode = "combine",
        ephemeral = true,
      })
    end
    return dec
  end,
}

return M
