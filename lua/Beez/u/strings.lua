local M = {}

--- Checks if string contains a substring
---@param sub string
---@return boolean
function string:contains(sub)
  ---@diagnostic disable-next-line: param-type-mismatch
  return self:find(sub, 1, true) ~= nil
end

--- Check if string starts with a substring
---@param start string
---@return boolean
function string:startswith(start)
  ---@diagnostic disable-next-line: param-type-mismatch
  return self:sub(1, #start) == start
end

--- Check if string ends with a substring
---@param ending string
---@return boolean
function string:endswith(ending)
  ---@diagnostic disable-next-line: param-type-mismatch
  return ending == "" or self:sub(-#ending) == ending
end

--- Replaces all instances of a substring with another substring
---@param old string
---@param new string
---@return string
function string:replace(old, new)
  local s = self
  local search_start_idx = 1

  while true do
    ---@diagnostic disable-next-line: param-type-mismatch
    local start_idx, end_idx = s:find(old, search_start_idx, true)
    if not start_idx then break end

    ---@diagnostic disable-next-line: param-type-mismatch
    local postfix = s:sub(end_idx + 1)
    ---@diagnostic disable-next-line: param-type-mismatch
    s = s:sub(1, (start_idx - 1)) .. new .. postfix

    search_start_idx = -1 * postfix:len()
  end

---@diagnostic disable-next-line: return-type-mismatch
  return s
end

--- Creates a hash out of specified string
---@param str string
---@return number
function M.hash(str)
  local h = 5381

  for i = 1, #str do
    h = h * 32 + h + str:byte(i)
  end
  return h
end

--- Generates randome string
---@param seed number?
---@return string
function M.uuid(seed)
  math.randomseed((seed or 0) + os.time())
  local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
  ---@diagnostic disable-next-line: redundant-return-value
  return string.gsub(template, "[xy]", function(c)
    local v = (c == "x") and math.random(0, 0xf) or math.random(8, 0xb)
    return string.format("%x", v)
  end)
end

--- Escapes a string for patern matching
---@param text string
---@return string
function M.escape_pattern(text)
  ---@diagnostic disable-next-line: redundant-return-value
  return text:gsub("([^%w])", "%%%1")
end

--- Trims trailing whitespace from a string
---@param s string
---@return string
function M.trimr(s)
  local ts = (s:gsub("(.-)%s*$", "%1"))
  return ts
end

--- Trims leading whitespace from a string
---@param s string
---@return string
function M.trim(s)
  ---@diagnostic disable-next-line: redundant-return-value
  return string.gsub(s, "^%s+", "")
end

return M
