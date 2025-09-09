local Buf = require("Beez.bufswitcher.buf")
local u = require("Beez.u")

---@class Beez.codestacks.buf
---@field id integer
---@field path string
---@field basename string
---@field dirname string
---@field current boolean

---@class Beez.codestacks.buflist
---@field bufs Beez.codestacks.buf[]
Bufferlist = {}
Bufferlist.__index = Bufferlist

--- Instantiate a new Buflist
---@return Beez.codestacks.buflist
function Bufferlist:new()
  local b = {}
  setmetatable(b, Bufferlist)

  b.bufs = {}
  return b
end

--- Checks if a buffer is valid
---@param buf Beez.codestacks.buf
---@return boolean
function Bufferlist.is_buf_valid(buf)
  local buf_info = vim.fn.getbufinfo(buf.id)[1]
  local buftype = vim.bo[buf.id].buftype
  local valid = buf.path ~= ""
    and vim.api.nvim_buf_is_valid(buf.id)
    and buf.basename ~= nil
    and buf.basename ~= ""
    and buftype ~= "nofile"
    and buf_info.listed == 1

  return valid
end

--- Add a buffer to the list
---@param bufnr integer
---@return boolean, Beez.codestacks.buf?
function Bufferlist:add(bufnr)
  -- Remove the buffer if it already exists
  self:remove(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false, nil
  end
  local path = vim.api.nvim_buf_get_name(bufnr)

  -- Buffer doesnt exists, create a new one
  ---@type Beez.codestacks.buf
  local buf = {
    id = bufnr,
    path = path,
    dirname = u.paths.dirname(path),
    basename = u.paths.basename(path),
    current = false,
  }
  if not Bufferlist.is_buf_valid(buf) then
    return false, buf
  end

  -- Add a new buffer to the front
  table.insert(self.bufs, 1, buf)
  -- Set previous current bufs as not current
  for _, b in ipairs(self.bufs) do
    b.current = false
  end
  -- Set new buffer as current
  buf.current = true
  return true, buf
end

--- Remove a buffer from the list
---@return integer, Beez.codestacks.buf?
function Bufferlist:remove(bufnr)
  local i, buf = self:get(bufnr)
  if buf == nil then
    return 0, nil
  end
  table.remove(self.bufs, i)
  return i, buf
end

--- Gets the current buffer in the list
---@return Beez.codestacks.buf
function Bufferlist:current()
  for _, b in ipairs(self.bufs) do
    if b.current then
      return b
    end
  end
end

--- Find a buffer by buffer number
---@return integer, Beez.codestacks.buf?
function Bufferlist:get(bufnr)
  local i, buf = u.tables.find(self.bufs, function(b)
    return b.id == bufnr
  end)
  return i, buf
end

--- Sort buffer list by recency
---@param bufs Beez.codestacks.buf[]
---@param recent_paths string[]
---@return Beez.codestacks.buf[]
local function sort_by_recency(bufs, recent_paths)
  local recent_files = {}
  for i, path in ipairs(recent_paths) do
    recent_files[path] = #recent_paths - i
  end

  table.sort(bufs, function(a, b)
    local a_recent_idx = recent_files[a.path] or 0
    local b_recent_idx = recent_files[b.path] or 0
    return a_recent_idx > b_recent_idx
  end)
  return bufs
end

--- List buffers
---@param recent_files string[]
---@return Beez.codestacks.buf[]
function Bufferlist:list(recent_files)
  local bufs = {}

  for _, b in ipairs(self.bufs) do
    local valid = true
    if valid then
      table.insert(bufs, b)
    end
  end

  bufs = sort_by_recency(bufs, recent_files)
  return bufs
end

return Bufferlist
