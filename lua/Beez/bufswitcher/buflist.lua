local Buf = require("Beez.bufswitcher.buf")
local u = require("Beez.u")

---@class Beez.bufswitcher.buflist
---@field bufs Beez.bufswitcher.buf[]
Buflist = {}
Buflist.__index = Buflist

--- Instantiate a new Buflist
---@return Beez.bufswitcher.buflist
function Buflist:new()
  local b = {}
  setmetatable(b, Buflist)

  b.bufs = {}
  return b
end

--- Add a buffer to the list
---@param bufnr integer
---@return boolean, Beez.bufswitcher.buf?
function Buflist:add(bufnr)
  -- Remove the buffer if it already exists
  self:remove(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false, nil
  end

  -- Buffer doesnt exists, create a new one
  local buf = Buf:new(bufnr)
  if not buf:is_valid() then
    return false, buf
  end

  -- Add a new buffer to the front
  table.insert(self.bufs, 1, buf)
  -- Set previous current bufs as not current
  for _, b in ipairs(self.bufs) do
    b:set_current(false)
  end
  -- Set new buffer as current
  buf:set_current()
  return true, buf
end

--- Remove a buffer from the list
---@return integer, Beez.bufswitcher.buf?
function Buflist:remove(bufnr)
  local i, buf = self:get(bufnr)
  if buf == nil then
    return 0, nil
  end
  table.remove(self.bufs, i)
  return i, buf
end

--- Gets the current buffer in the list
---@return Beez.bufswitcher.buf
function Buflist:current()
  for _, b in ipairs(self.bufs) do
    if b.current then
      return b
    end
  end
end

--- Find a buffer by buffer number
---@return integer, Beez.bufswitcher.buf?
function Buflist:get(bufnr)
  local i, buf = u.tables.find(self.bufs, function(b)
    return b.id == bufnr
  end)
  return i, buf
end

--- Sort buffer list by recency
---@param bufs Beez.bufswitcher.buf[]
---@param recent_paths string[]
---@return Beez.bufswitcher.buf[]
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
---@param opts? {sort?: "recency"}
---@return Beez.bufswitcher.buf[]
function Buflist:list(opts)
  local bs = require("Beez.bufswitcher")
  opts = opts or {}
  -- No filters
  if opts == {} then
    return self.bufs
  end
  local bufs = {}

  for _, b in ipairs(self.bufs) do
    local valid = true
    if valid then
      table.insert(bufs, b)
    end
  end

  if opts.sort == nil or opts.sort == "recency" then
    bufs = sort_by_recency(bufs, bs.rl:list())
  end
  return bufs
end

return Buflist
