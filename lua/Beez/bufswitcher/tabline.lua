local c = require("Beez.bufswitcher.config")
local M = {}

--- Generate a tabline for rendering buffers
---@param bufs Beez.bufswitcher.buf[]
---@return string
function M.get(bufs)
  local tabline = ""
  local pin_start = false
  for _, b in ipairs(bufs) do
    if b.pinned and not pin_start then
      pin_start = true
      tabline = tabline .. " 📌  "
    end
    local buf_tabline = M.buf(b, b.label[1], b.label[2])
    tabline = tabline .. buf_tabline .. " "
  end
  return tabline
end

--- Generate a tabline for rendering a single buffer
---@param b Beez.bufswitcher.buf
---@param label string
---@param label_hl string
---@return string
function M.buf(b, label, label_hl)
  local label_tabline = M.label(label, label_hl)
  local buf_tabline = M.name(b.name, label)
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
    tabline = tabline .. "%#" .. hl .. "#" .. name
  end
  return tabline
end

--- Generate a tabline to render the label for a buffer
---@param label string
---@param hl string
---@return string
function M.label(label, hl)
  if label == "" then
    return ""
  end
  local tabline = "%#" .. hl .. "#" .. label
  return tabline
end

return M
