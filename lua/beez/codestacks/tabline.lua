local c = require("beez.codestacks.config")
local M = {}

---@class Beez.codestacks.tabline.display_buf
---@field label string[]
---@field name string[][]
---@field pinned boolean
---@field space boolean

--- Generate a tabline for rendering buffers
---@param stack string
---@param bufs Beez.codestacks.tabline.display_buf[]
---@return string
function M.get(stack, bufs)
  local tabline = M.stack(stack)
  tabline = tabline .. M.hl(" 󰓩 ", c.config.ui_buf_sep_hl) .. M.space()
  local pin_start = false
  for _, b in ipairs(bufs) do
    if b.pinned and not pin_start then
      pin_start = true
      tabline = tabline .. M.hl(" 󰐃 ", c.config.ui_pin_sep_hl) .. M.space()
    end
    local buf_tabline = M.buf(b)
    tabline = tabline .. buf_tabline
    if b.space ~= false then
      tabline = tabline .. M.space()
    end
  end
  return tabline
end

--- Generate a tabline for rending some text with highlight
---@param text string
---@param hl string
---@return string
function M.hl(text, hl)
  local tabline = "%#" .. hl .. "#" .. text
  return tabline
end

--- Generate a tabline for rendering stack name along with separator
---@param stack string
---@return string
function M.stack(stack)
  local tabline = M.hl("", c.config.ui_stack_sep_hl)
    .. M.space()
    .. M.hl(stack, c.config.ui_stack_hl)
    .. M.space()
  return tabline
end

--- Generate a tabline for rendering a single buffer
---@param b Beez.codestacks.tabline.display_buf
---@return string
function M.buf(b)
  local label_tabline = M.hl(b.label[1], b.label[2])
  local buf_tabline = M.name(b.name, b.label[1])
  local tabline = label_tabline .. buf_tabline
  return tabline
end

--- Generate a tabline to render the name of a buffer
---@param name_with_highlights string[][]
---@param label string
---@return string
function M.name(name_with_highlights, label)
  local tabline = ""
  for i, n in ipairs(name_with_highlights) do
    local name = n[1]
    if i == 1 and label ~= "" and name:startswith(label) then
      name = name:sub(2)
    end
    local hl = n[2] or c.config.ui_name_hl
    tabline = tabline .. M.hl(name, hl)
  end
  return tabline
end

--- Generate a tabline to render whitespace
---@return string
function M.space()
  local hl = "Normal"
  return M.hl(" ", hl)
end

return M
