local M = {}

--- Map over each element in the table
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

--- Return a table of values in the table
---@param tbl table
---@return string[]
function M.values(tbl)
  local values = {}
  for _, v in pairs(tbl) do
    table.insert(values, v)
  end
  return values
end

--- Find an element in the table
---@param tbl table
---@param f fun(v: any): boolean
---@return any?
function M.find(tbl, f)
  for _, v in pairs(tbl) do
    if f(v) then
      return v
    end
  end
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

--- Extends a table with another table
---@param t table
---@vararg table
---@return table
function M.extend(t, ...)
  for _, v in ipairs({ ... }) do
    if type(v) == "table" then
      for _, val in pairs(v) do
        table.insert(t, val)
      end
    else
      table.insert(t, v)
    end
  end
  return t
end

--- Removes a value from a table
---@param t table
---@param rv any|fun(v: any): boolean
---@return any?
function M.remove(t, rv)
  for i, v in ipairs(t) do
    if (type(rv) == "function" and rv(v)) or rv == v then
      table.remove(t, i)
      return v
    end
  end
end

--- Count length of table, handles dictionary as well
---@param t table
---@return integer
function M.len(t)
  local count = 0
  for _, _ in pairs(t) do
    count = count + 1
  end
  return count
end

return M
