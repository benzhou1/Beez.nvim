local M = {
  p = {
    line_with_start_char = "([%w%._%-%\"%']+.*)$",
    middle_of_arg_dict = ".*[%(%,%=%:]%s*([%w%.%_%-%\"%'%(%)%s]+)$",
    func_type = "%s*->%s*[%w%.%_%-%\"%'%(%)%s]+$",
  },
}

--- Match postfix matches with a specific prefix.
---@param p table|string
---@param prefixes string|string[]
---@return string, string
function M.pf_match_without_prefix(p, prefixes)
  local match = p
  if type(p) ~= "string" then
    match = p.snippet.env.POSTFIX_MATCH
  end
  if type(prefixes) == "string" then
    prefixes = { prefixes }
  end
  for _, prefix in ipairs(prefixes) do
    local pattern = "^" .. prefix .. " "
    local matched_prefix = match:match(pattern)
    if matched_prefix then
      match = match:gsub(pattern, "")
      return matched_prefix, match
    end
  end
  ---@diagnostic disable-next-line: return-type-mismatch
  return "", match
end

--- Match postfix mathes delimited by spaces.
---@param p table|string
---@param opts? {slice: number, concat: string}
---@return string[]
function M.pf_match_space_delimited(p, opts)
  opts = opts or {}
  local match = p
  if type(p) ~= "string" then
    match = p.snippet.env.POSTFIX_MATCH
  end
  if match == "" or not match then
    return {}
  end

  local words = {}
  for word in match:gmatch("[^%s]+") do
    table.insert(words, word)
  end

  if opts.slice then
    local u = require("Beez.u")
    local new_matches = {}
    for i = 1, opts.slice - 1 do
      if words[i] then
        table.insert(new_matches, words[i])
      end
    end
    if opts.slice <= #words then
      table.insert(new_matches, table.concat(u.tables.slice(words, opts.slice), opts.concat or " "))
    end
    return new_matches
  end
  return words
end

--- Match postfix matches and handle if the match is in the middle of a line.
---@param p table|string
---@param end_pattern string
---@param opts? {slice: number}
---@return string, string[]
function M.pf_match_middle_of_line(p, end_pattern, opts)
  opts = opts or {}
  local match = p
  if type(p) ~= "string" then
    match = p.snippet.env.POSTFIX_MATCH
  end
  if match == "" or not match then
    return "", {}
  end

  local end_match = match:match(end_pattern)
  local start = ""
  print("end_match =", vim.inspect(end_match))
  if end_match then
    -- Remove the end match from the postfix match, leaving just the start of of the line
    start = match:gsub("(.*)" .. end_match:gsub("([^%w])", "%%%1") .. "$", "%1")
    match = end_match
  end

  print("match =", vim.inspect(match))
  if opts.slice then
    match = M.pf_match_space_delimited(match, { slice = opts.slice })
  end
  return start, match
end

return M
