local M = {}

--- Map over each element in the table
---@param tbl table
---@param f fun(v: any): boolean
---@return table
function M.map(tbl, f)
  local t = {}
  for k, v in pairs(tbl) do
    t[k] = f(v)
  end
  return t
end

--- Return a table of keys in the table
---@param tbl table
---@return string[]
function M.keys(tbl)
  local keys = {}
  for k, v in pairs(tbl) do
    table.insert(keys, k)
  end
  return keys
end

--- Find an element in the table
---@param tbl table
---@param f fun(v: any): boolean
---@return any?
function M.find(tbl, f)
  for k, v in pairs(tbl) do
    if f(v) then
      return v
    end
  end
  return nil
end

--- Reverse the order of a table
---@param tbl table
---@return table
function M.reverse(tbl)
  local reversed = {}
  for i = #tbl, 1, -1 do
    table.insert(reversed, tbl[i])
  end
  return reversed
end

return M
