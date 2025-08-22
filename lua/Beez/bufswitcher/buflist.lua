local Buf = require("Beez.bufswitcher.buf")
local u = require("Beez.u")

---@class Beez.bufswitcher.data
---@field pinned {path: string, label: string}[]

---@class Beez.bufswitcher.buflist
---@field bufs Beez.bufswitcher.buf[]
---@field pinned {path: string, label: string}[]
---@field dir_path string
---@field pins_path string
Buflist = {}
Buflist.__index = Buflist

--- Instantiate a new Buflist
---@param dir_path string
---@return Beez.bufswitcher.buflist
function Buflist:new(dir_path)
  local b = {}
  setmetatable(b, Buflist)

  b.dir_path = dir_path
  b.pins_path = vim.fs.joinpath(dir_path, "pinned.json")
  b.bufs = {}
  b.pinned = {}
  return b
end

--- Load from persisted data file
function Buflist:load()
  if vim.fn.filereadable(self.pins_path) == 0 then
    vim.fn.writefile({ "{}" }, self.pins_path)
    return
  end

  local file = io.open(self.pins_path, "r")
  local data
  if file then
    local lines = file:read("*a")
    ---@type Beez.bufswitcher.data
    data = vim.fn.json_decode(lines)
    file:close()
  else
    error("Could not open file: " .. self.pins_path)
  end

  if data ~= nil then
    for _, d in ipairs(data.pinned) do
      -- Load pinned buffers
      local bufnr = vim.fn.bufnr(d.path, true)
      vim.fn.bufload(bufnr)
      vim.bo[bufnr].buflisted = true

      local buf = Buf:new(d.path)
      if buf:is_valid() then
        buf:pin(d.label)
        table.insert(self.bufs, buf)
        table.insert(self.pinned, d)
      end
    end
  end
end

--- Persist data to a file
function Buflist:save()
  ---@type Beez.bufswitcher.data
  local data = { pinned = self.pinned }
  local json_string = vim.fn.json_encode(data)
  local file = io.open(self.pins_path, "w")
  assert(file, "Could not open file for writing: " .. self.pins_path)
  file:write(json_string)
  file:close()
end

--- Add a buffer to the list
---@param bufnr integer
function Buflist:add(bufnr)
  -- Remove the buffer if it already exists
  local _, buf = self:remove(bufnr)
  -- Buffer doesnt exists, create a new one
  if buf == nil then
    local filename = vim.api.nvim_buf_get_name(bufnr)
    buf = Buf:new(filename)
  end

  if not buf:is_valid() then
    return
  end

  -- Add a new buffer to the front
  table.insert(self.bufs, 1, buf)
  -- Set new buffer as current
  for _, b in ipairs(self.bufs) do
    b:set_current(false)
  end
  buf:set_current()
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
function Buflist:current()
  for _, b in ipairs(self.bufs) do
    if b.current then
      return b
    end
  end
end

--- Pin a buffer
---@param label string
function Buflist:pin(label)
  local buf = self:current()
  buf:pin(label)

  -- Override existing pin with same label
  local removed_pinned = u.tables.remove(self.pinned, function(b)
    return b.label == label
  end)
  if removed_pinned ~= nil then
    -- Make sure to unpin the existing buffer
    local _, exist_buf = u.tables.find(self.bufs, function(b)
      return b.path == removed_pinned.path
    end)
    if exist_buf ~= nil then
      exist_buf:unpin()
    end
  end
  table.insert(self.pinned, {
    path = buf.path,
    label = label,
  })
end

--- Unpin a buffer
function Buflist:unpin()
  local buf = self:current()
  buf:unpin()
  u.tables.remove(self.pinned, function(b)
    return b.path == buf.path
  end)
end

--- Find a buffer with specified options
---@return integer, Beez.bufswitcher.buf?
function Buflist:get(bufnr)
  local filename = vim.api.nvim_buf_get_name(bufnr)
  local i, buf = u.tables.find(self.bufs, function(b)
    return b.path == filename
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

--- Sort buffer list by pinned files
---@param bufs Beez.bufswitcher.buf[]
---@param pinned_paths {path: string, label: string}[]
---@return Beez.bufswitcher.buf[]
local function sort_by_pinned(bufs, pinned_paths)
  local pinned_files = {}
  for i, p in ipairs(pinned_paths) do
    pinned_files[p.path] = #pinned_paths - i
  end

  table.sort(bufs, function(a, b)
    local a_recent_idx = pinned_files[a.path] or 0
    local b_recent_idx = pinned_files[b.path] or 0
    return a_recent_idx > b_recent_idx
  end)
  return bufs
end

--- List buffers
---@param opts? {pinned?: boolean, sort?: "recency"}
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
    if opts.pinned ~= nil then
      if (opts.pinned and not b.pinned) or (not opts.pinned and b.pinned) then
        valid = false
      end
    end
    if valid then
      table.insert(bufs, b)
    end
  end

  if opts.pinned then
    bufs = sort_by_pinned(bufs, self.pinned)
  elseif opts.sort == nil or opts.sort == "recency" then
    bufs = sort_by_recency(bufs, bs.rl:list())
  end
  return bufs
end

return Buflist
