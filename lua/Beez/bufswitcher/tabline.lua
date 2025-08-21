local c = require("Beez.bufswitcher.config")
local M = {}

function M.get(bufs)
  local tabline = ""
  local pin_start = false
  for _, b in ipairs(bufs) do
    if b.pinned and not pin_start then
      pin_start = true
      tabline = tabline .. "%#" .. c.config.ui_separator_hl .. "#│ "
    end
    local buf_tabline = M.buf(b, b.label[1], b.label[2])
    tabline = tabline .. buf_tabline .. " "
  end
  return tabline
end

function M.buf(b, label, label_hl)
  local label_tabline = M.label(label, label_hl)
  local buf_tabline = M.name(b.name)
  local tabline = label_tabline .. buf_tabline
  return tabline
end

function M.name(name_with_highlights)
  local tabline = ""
  for _, n in ipairs(name_with_highlights) do
    local name = n[1]
    local hl = n[2] or c.config.ui_name_hl
    tabline = tabline .. "%#" .. hl .. "#" .. name
  end
  return tabline
end

function M.label(label, hl)
  if label == "" then
    return ""
  end
  local tabline = "%#" .. hl .. "#" .. label
  return tabline
end

return M
