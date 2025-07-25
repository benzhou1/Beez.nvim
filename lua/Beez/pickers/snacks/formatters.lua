local u = require("Beez.u")
local M = {}

--- Formats live grep entries to show line first and filename aligned to the end
---@return fun(item: snacks.picker.Item, picker: snacks.Picker):snacks.picker.Highlight[]
function M.grep()
  local snacks_format = require("snacks.picker.format")

  ---@param item snacks.picker.Item
  ---@param picker snacks.Picker
  ---@return snacks.picker.Highlight[]
  return function(item, picker)
    local line = ""
    if item.line then
      line = u.strs.trim(item.line)
      ---@diagnostic disable-next-line: param-type-mismatch, undefined-field
      if line:startswith('"') then
        line = string.gsub(line, '"', "")
      end
    end

    -- Get file name only by modifying opts.formatters.file.filename_only
    local old_filename_only = picker.opts.formatters.file.filename_only
    picker.opts.formatters.file.filename_only = true
    local _filename_parts = snacks_format.filename(item, picker)
    picker.opts.formatters.file.filename_only = old_filename_only

    -- Use max width to calculate space between line and file name
    local max_width = picker.input.win.opts.max_width - 2
    local spaces = max_width - u.utf8.len(line)
    local filename_parts = {}
    for i, p in ipairs(_filename_parts) do
      spaces = spaces - u.utf8.len(p[1])
      table.insert(filename_parts, p)
      if i > 2 then
        break
      end
    end

    -- Truncate line if we dont have enough space
    if spaces <= 0 then
      line = string.sub(line, 1, u.utf8.len(line) - math.abs(spaces) - 1 - 3)
    end

    local ret = {}
    Snacks.picker.highlight.format(item, line, ret)
    if spaces > 0 then
      table.insert(ret, { " ", "String" })
      table.insert(ret, { string.rep(" ", spaces), "String" })
    else
      table.insert(ret, { "...  ", "String" })
    end
    vim.list_extend(ret, filename_parts)
    return ret
  end
end

function M.grep_notes()
  ---@param item snacks.picker.Item
  ---@param picker snacks.Picker
  ---@return snacks.picker.Highlight[]
  return function(item, picker)
    local gtext = ""
    if item.gtext then
      gtext = u.strs.trim(item.gtext)
      ---@diagnostic disable-next-line: param-type-mismatch, undefined-field
      if gtext:startswith('"') then
        gtext = string.gsub(gtext, '"', "")
      end
    end

    -- Use max width to calculate space between line and file name
    local max_width = picker.input.win.opts.max_width - 2
    local spaces = max_width - u.utf8.len(gtext) - u.utf8.len(item.title)

    -- Truncate line if we dont have enough space
    if spaces <= 0 then
      gtext = string.sub(gtext, 1, u.utf8.len(gtext) - math.abs(spaces) - 1 - 3)
    end

    local ret = {}
    table.insert(ret, { gtext, "String" })
    if spaces > 0 then
      table.insert(ret, { " ", "String" })
      table.insert(ret, { string.rep(" ", spaces), "String" })
    else
      table.insert(ret, { "...  ", "String" })
    end
    if item.title ~= gtext then
      table.insert(ret, { item.title, "SnacksPickerFile" })
    end
    return ret
  end
end

return M
