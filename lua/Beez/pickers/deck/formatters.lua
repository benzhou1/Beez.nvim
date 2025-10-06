local u = require("Beez.u")
local M = {}

--- Shows filename first followed by dirname
M.filename_first = {
  transform = function(opts)
    return function(item)
      local filename = item.data.filename
      if not filename then
        return
      end
      if item.data.filename:endswith(u.paths.sep) then
        filename = item.data.filename:sub(1, -2)
      end
      local basename = u.paths.basename(filename)
      local dirname = u.paths.dirname(filename)
      ---@diagnostic disable-next-line: param-type-mismatch
      if dirname:startswith(opts.cwd) then
        dirname = dirname:gsub(opts.cwd, "")
        ---@diagnostic disable-next-line: param-type-mismatch
        if dirname:startswith(u.paths.sep) then
          dirname = dirname:sub(2)
        end
      end

      if item.data.lnum then
        item.display_text = {
          { basename, "SnacksPickerFile" },
          { ":", "String" },
          { tostring(item.data.lnum), "Comment" },
          { " ", "String" },
          { dirname, "SnacksPickerDir" },
        }
      else
        item.display_text = {
          { basename, "SnacksPickerFile" },
          { " ", "String" },
          { dirname, "Comment" },
        }
      end
    end
  end,
}

M.grep = {
  --- Transform output of grep
  ---@param item deck.ItemSpecifier
  ---@param text string
  transform = function(item, text, root_dir)
    local Path = require("plenary.path")
    local filename = text:match("^[^:]+")
    local lnum = tonumber(text:match(":(%d+):"))
    local col = tonumber(text:match(":%d+:(%d+):"))
    local match = text:match(":%d+:%d+:(.*)$")
    item.display_text = {
      { filename, "Comment" },
      { " ", "String" },
      { "(" .. lnum .. ":" .. col .. "): ", "Comment" },
      { " ", "String" },
    }
    local start_idx, end_idx = string.find(string.lower(match), string.lower(item.data.query))
    if start_idx ~= nil then
      local before_match = string.sub(match, 1, start_idx - 1)
      local query_match = string.sub(match, start_idx, end_idx)
      local after_match = string.sub(match, end_idx + 1)
      ---@diagnostic disable-next-line: param-type-mismatch
      table.insert(item.display_text, { before_match, "String" })
      ---@diagnostic disable-next-line: param-type-mismatch
      table.insert(item.display_text, { query_match, "Search" })
      ---@diagnostic disable-next-line: param-type-mismatch
      table.insert(item.display_text, { after_match, "String" })
    else
      ---@diagnostic disable-next-line: param-type-mismatch
      table.insert(item.display_text, { match, "String" })
    end
    item.data.filename = Path:new(root_dir):joinpath(filename).filename
    item.data.lnum = lnum
    item.data.col = col
    item.data.match = match
  end,
}

--- Converts ctag address to searchable tag
---@param text string
---@return string
local function to_ctag(text)
  local ctag = text:match(".-[/\\](^?.*)[/\\]")
  -- if tag name contains a slash we could
  -- have the wrong match, most tags start
  -- with ^ so try to match based on that
  ctag = ctag and ctag:match("[/\\]^(.*)") or ctag
  if ctag then
    -- required escapes for vim.fn.search()
    -- \ ] ~ *
    ctag = ctag:gsub("[\\%]~*]", function(x)
      return "\\" .. x
    end)
  end
  ctag = ctag:match([[(.*);"]]) or ctag -- remove ctag comments
  return ctag
end

---@class Beez.ctagsparsed
---@field symbol string
---@field filename string
---@field address string
---@field basename string
---@field parentname string
---@field symbol_before? string
---@field symbol_center? string
---@field symbol_after? string
---@field match string
---@field match_before? string
---@field match_center? string
---@field match_after? string
--- Parse ctags output
---@param text string
---@param query string
---@return Beez.ctagsparsed
local function parse_ctags(text, query)
  ---@type Beez.ctagsparsed
  local parsed = {}
  local symbol, filename, address = text:match("([^\t]+)\t([^\t]+)\t(.*)")
  local basename = u.paths.basename(filename)
  local parentname = u.paths.basename(u.paths.dirname(filename))
  parsed.symbol = symbol
  parsed.filename = filename
  parsed.address = address
  parsed.basename = basename
  parsed.parentname = parentname

  local start_idx, end_idx = string.find(string.lower(symbol), string.lower(query))
  if start_idx ~= nil and end_idx ~= nil then
    local before_match = string.sub(symbol, 1, start_idx - 1)
    local query_match = string.sub(symbol, start_idx, end_idx)
    local after_match = string.sub(symbol, end_idx + 1)
    parsed.symbol_before = before_match
    parsed.symbol_center = query_match
    parsed.symbol_after = after_match
  end

  local match = address:match('/^(.*)$?/;"')
  if match:endswith("$") then
    match = match:sub(1, -2)
  end
  parsed.match = match
  start_idx, end_idx = string.find(string.lower(match), string.lower(query))
  if start_idx ~= nil and end_idx ~= nil then
    local before_match = string.sub(match, 1, start_idx - 1)
    local query_match = string.sub(match, start_idx, end_idx)
    local after_match = string.sub(match, end_idx + 1)
    parsed.match_before = before_match
    parsed.match_center = query_match
    parsed.match_after = after_match
  end
  return parsed
end

M.ctags = {
  transform = function(workspace)
    return function(item, text)
      if text:startswith("!_TAG") then
        return
      end
      local parsed = parse_ctags(text, item.data.query)
      item.data.filename = parsed.filename
      item.data.ctag = to_ctag(parsed.address)
      item.display_text = {}
      if workspace then
        table.insert(item.display_text, { parsed.parentname .. "/" .. parsed.basename, "Comment" })
        table.insert(item.display_text, { " ", "String" })
      end

      if parsed.symbol_center ~= nil then
        table.insert(item.display_text, { parsed.symbol_before, "String" })
        table.insert(item.display_text, { parsed.symbol_center, "Search" })
        table.insert(item.display_text, { parsed.symbol_after, "String" })
      else
        table.insert(item.display_text, { parsed.symbol, "String" })
      end
      table.insert(item.display_text, { " ", "String" })

      local hl = "String"
      if not workspace then
        hl = "Comment"
      end
      if parsed.match_center ~= nil then
        table.insert(item.display_text, { parsed.match_before, hl })
        table.insert(item.display_text, { parsed.match_center, "Search" })
        table.insert(item.display_text, { parsed.match_after, hl })
      else
        table.insert(item.display_text, { parsed.match, hl })
      end
    end
  end,
}

return M
