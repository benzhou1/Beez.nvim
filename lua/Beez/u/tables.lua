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

--- Slices a table
---@param tbl table
---@param first integer
---@param last? integer
---@return table
function M.slice(tbl, first, last)
  local sliced = {}
  for i = first, last or #tbl do
    sliced[#sliced + 1] = tbl[i]
  end
  return sliced
end

--- Delete keys from a table
---@param tbl table
---@param keys Beez.u.plugin.spec.delkeys[]
---@return table
function M.remove_keys(tbl, keys)
  for _, key in ipairs(keys) do
    if type(key) == "string" then
      tbl[key] = nil
    else
      -- Keys is a table of keys, drill down into the table
      local curr_tbl = tbl
      local _k = nil
      for _, k in ipairs(key) do
        if curr_tbl ~= nil then
          curr_tbl = curr_tbl[k]
        end
        _k = k
      end
      -- Did we succiessfullly find the key to delete?
      if curr_tbl ~= nil then
        curr_tbl[_k] = nil
      end
    end
  end
  return tbl
end

--- Pick only keys from a table
---@param tbl table
---@param keys Beez.u.plugin.spec.delkeys[]
---@return table
function M.pick_keys(tbl, keys)
  local new_table = {}
  for _, key in ipairs(keys) do
    if type(key) == "string" then
      new_table[key] = tbl[key]
    else
      -- Keys is a table of keys, drill down into the table
      local curr_tbl = tbl
      local curr_new_tbl = new_table
      local _k = nil
      for _, k in ipairs(key) do
        if curr_tbl ~= nil then
          curr_tbl = curr_tbl[k]
          -- Create empty tables as we drill down
          curr_new_tbl[k] = {}
          curr_new_tbl = curr_new_tbl[k]
        end
        _k = k
      end
      -- Did we succiessfullly find the key to pick?
      if curr_tbl ~= nil then
        curr_new_tbl[_k] = curr_tbl[_k]
      end
    end
  end
  return new_table
end

return M
