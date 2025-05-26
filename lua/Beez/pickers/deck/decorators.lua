local u = require("Beez.u")
local M = {}

-- Just decorator for buffer flags without icons
M.buf_flags = {
  name = "buf_flags",
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
      local ok, _ = pcall(require, "bufferline")
      if ok then
        local elements = require("bufferline.commands").get_elements()
        local groups = require("bufferline.groups")
        for _, e in ipairs(elements.elements) do
          if e.id == buf and groups._is_pinned(e) then
            table.insert(dec, {
              col = 0,
              virt_text = { { "📌 " } },
              epheremal = true,
              virt_text_pos = "inline",
            })
            break
          end
        end
      end
    end
    return dec
  end,
}

return M
